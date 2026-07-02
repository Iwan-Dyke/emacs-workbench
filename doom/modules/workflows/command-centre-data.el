;;; workflows/command-centre-data.el -*- lexical-binding: t; -*-

;; Data collection for the command centre: shell helpers, Jira fetching,
;; git/repo status, infra checks, team data collection.

;;; ── Config ─────────────────────────────────────────────────────────────────

(defvar workbench-cc--jira-project nil
  "Jira project key for the command centre. Set in profiles/local.el.")
(defvar workbench-cc--jira-user nil
  "Jira username (email) for the command centre. Set in profiles/local.el.")
(defvar workbench-cc--git-author nil
  "Git author name fragment for filtering commits. Set in profiles/local.el.")
(defvar workbench-cc--code-root "~/code/"
  "Root directory to scan for git repositories.")
(defvar workbench-cc--spark-url "http://localhost:8888"
  "URL to health-check the local Spark environment.")

;; Team lead view config (ADR 0063)
(defvar workbench-cc--team-name nil
  "Team display name for the team lead view. Set in profiles/local.el.")
(defvar workbench-cc--team-id nil
  "Jira team UUID for JQL filtering. Set in profiles/local.el.")
(defvar workbench-cc--team-wip-limit 2
  "WIP limit for the team (items In Progress).")
(defvar workbench-cc--team-members nil
  "List of team member display names for filtering.
Set in profiles/local.el as a list of strings.")

;; Team board statuses (may differ from main board statuses)
(defvar workbench-cc--team-status-next "Next"
  "Status name for the team's 'next up' column.")
(defvar workbench-cc--team-status-wip "In Progress"
  "Status name for the team's active work column.")
(defvar workbench-cc--team-status-done "Done"
  "Status name for the team's completed column.")

;;; ── Shell Helpers ──────────────────────────────────────────────────────────

(defun workbench-cc--shell (dir &rest args)
  "Run ARGS in DIR, return trimmed stdout or nil."
  (let ((default-directory (expand-file-name (or dir "~/"))))
    (with-temp-buffer
      (when (zerop (apply #'call-process (car args) nil t nil (cdr args)))
        (string-trim (buffer-string))))))

(defun workbench-cc--shell-lines (dir &rest args)
  "Run ARGS in DIR, return non-empty lines."
  (when-let ((out (apply #'workbench-cc--shell dir args)))
    (and (not (string-empty-p out))
         (split-string out "\n" t))))

(defun workbench-cc--shell-or-error (dir &rest args)
  "Run ARGS in DIR. Return (:ok OUTPUT) or (:error REASON).
Distinguishes command-not-found, non-zero exit, and empty output."
  (let ((default-directory (expand-file-name (or dir "~/")))
        (cmd (car args)))
    (if (not (executable-find cmd))
        (list :error (format "%s not found" cmd))
      (with-temp-buffer
        (let ((exit (apply #'call-process cmd nil t nil (cdr args))))
          (if (zerop exit)
              (list :ok (string-trim (buffer-string)))
            (list :error (format "%s exited %d" cmd exit))))))))

;;; ── Jira ───────────────────────────────────────────────────────────────────

(defun workbench-cc--error-p (result)
  "Return non-nil if RESULT is an error plist from a fetch function."
  (and (consp result) (eq :error (car result))))

(defun workbench-cc--error-reason (result)
  "Return the error reason string from RESULT."
  (cadr result))

(defun workbench-cc--jira-tickets ()
  "Fetch In Progress tickets. Returns list of plists, or (:error REASON)."
  (if (not (and workbench-cc--jira-project workbench-cc--jira-user))
      (list :error "Jira project/user not configured")
    (let ((result (workbench-cc--shell-or-error
                   nil "jira" "issue" "list"
                   "-p" workbench-cc--jira-project
                   "-a" workbench-cc--jira-user
                   "-s" "In Progress"
                   "--plain" "--no-headers"
                   "--columns" "KEY,SUMMARY,TYPE,UPDATED")))
      (if (eq :error (car result))
          result
        (let ((output (cadr result)))
          (if (string-empty-p output)
              '()
            (mapcar (lambda (line)
                      (let ((parts (split-string line "\t+" nil)))
                        (list :key (string-trim (or (nth 0 parts) ""))
                              :summary (string-trim (or (nth 1 parts) ""))
                              :type (string-trim (or (nth 2 parts) ""))
                              :updated (string-trim (or (nth 3 parts) "")))))
                    (split-string output "\n" t))))))))

(defun workbench-cc--ticket-last-comment-date (key)
  "Get date of last comment on KEY, or nil."
  (when-let ((output (workbench-cc--shell
                      nil "jira" "issue" "view" key "--plain")))
    ;; Pattern: "Author • Date • Latest comment"
    (when (string-match "• \\([A-Z][a-z]+, [0-9]+ [A-Z][a-z]+ [0-9]+\\) •" output)
      (match-string 1 output))))

(defun workbench-cc--ticket-details (key)
  "Get extra details for KEY: last comment snippet and parent."
  (when-let ((output (workbench-cc--shell
                      nil "jira" "issue" "view" key "--comments" "1" "--plain")))
    (let ((parent nil) (comment nil))
      ;; Parent: look for "Parent: KEY" or linked feature
      (when (string-match "Parent:\\s-*\\([A-Z]+-[0-9]+\\)" output)
        (setq parent (match-string 1 output)))
      ;; Last comment body: first non-empty line after "Latest comment"
      (when (string-match "Latest comment[^\n]*\n\\(?:\\s-*\n\\)*\\s-*\\(.+\\)" output)
        (setq comment (string-trim (match-string 1 output))))
      (list :parent parent :comment comment))))

(defun workbench-cc--ticket-commented-today-p (key)
  "Return t if KEY has a comment from today."
  (when-let ((date-str (workbench-cc--ticket-last-comment-date key)))
    (let ((today (format-time-string "%d %b %y")))
      (string-match-p (regexp-quote today) date-str))))

(defun workbench-cc--days-since-update (updated-str)
  "Return days since UPDATED-STR, or nil if unparseable."
  (condition-case nil
      (let* ((time (date-to-time updated-str))
             (diff (time-subtract (current-time) time)))
        (/ (float-time diff) 86400.0))
    (error nil)))

;;; ── Git / Repos ────────────────────────────────────────────────────────────

(defun workbench-cc--recent-repos ()
  "Get repos you committed to recently, ordered by last commit date."
  (let* ((dirs (directory-files (expand-file-name workbench-cc--code-root) t "^[^.]" t))
         (git-dirs (seq-filter (lambda (d)
                                 (file-directory-p (expand-file-name ".git" d)))
                               dirs))
         (with-commit (seq-filter #'identity
                        (mapcar (lambda (d)
                                  (when-let ((date (workbench-cc--shell
                                                    d "git" "log" "-1"
                                                    (concat "--author=" workbench-cc--git-author) "--format=%ct")))
                                    (cons d (string-to-number date))))
                                git-dirs)))
         (sorted (sort with-commit (lambda (a b) (> (cdr a) (cdr b))))))
    (seq-take (mapcar #'car sorted) 5)))

(defun workbench-cc--repo-status (dir)
  "Get git status plist for DIR."
  (let ((branch (workbench-cc--shell dir "git" "branch" "--show-current"))
        (dirty (workbench-cc--shell-lines dir "git" "status" "--porcelain"))
        (ab (workbench-cc--shell dir "git" "rev-list" "--left-right" "--count" "HEAD...@{upstream}"))
        (last-commit (workbench-cc--shell dir "git" "log" "-1" (concat "--author=" workbench-cc--git-author) "--format=%ar"))
        (last-msg (workbench-cc--shell dir "git" "log" "-1" (concat "--author=" workbench-cc--git-author) "--format=%s")))
    (let (ahead behind)
      (when (and ab (string-match "\\([0-9]+\\)\t\\([0-9]+\\)" ab))
        (setq ahead (string-to-number (match-string 1 ab))
              behind (string-to-number (match-string 2 ab))))
      (list :name (file-name-nondirectory dir)
            :branch (or branch "(detached)")
            :dirty (length (or dirty '()))
            :ahead (or ahead 0)
            :behind (or behind 0)
            :last-commit (or last-commit "")
            :last-msg (or last-msg "")))))

(defun workbench-cc--recent-commits ()
  "Get last 5 commits across all repos from the past 3 days, most recent first."
  (let* ((dirs (workbench-cc--recent-repos))
         (all nil))
    (dolist (dir dirs)
      (when-let ((lines (workbench-cc--shell-lines
                         dir "git" "log" "-5"
                         (concat "--author=" workbench-cc--git-author) "--since=3 days ago"
                         "--format=%ct|%ar|%s")))
        (dolist (line lines)
          (let ((parts (split-string line "|" nil)))
            (push (list :epoch (string-to-number (or (nth 0 parts) "0"))
                        :repo (file-name-nondirectory dir)
                        :time (or (nth 1 parts) "")
                        :msg (or (nth 2 parts) ""))
                  all)))))
    (seq-take (sort all (lambda (a b)
                          (> (plist-get a :epoch) (plist-get b :epoch))))
              5)))

;;; ── Infrastructure ─────────────────────────────────────────────────────────

(defun workbench-cc--infra-status ()
  "Check infrastructure health."
  (list :colima (not (null (workbench-cc--shell nil "colima" "status")))
        :containers (or (workbench-cc--shell-lines
                         nil "docker" "ps" "--format" "{{.Names}}")
                        '())
        :spark (condition-case nil
                   (eq 0 (call-process "curl" nil nil nil
                                       "-s" "-o" "/dev/null"
                                       "-w" "" "--max-time" "1"
                                       workbench-cc--spark-url))
                 (error nil))))

;;; ── Jira Done / Next ───────────────────────────────────────────────────────

(defun workbench-cc--jira-done ()
  "Fetch recently Done tickets (last 3). Returns list of plists, or (:error REASON)."
  (if (not (and workbench-cc--jira-project workbench-cc--jira-user))
      (list :error "Jira project/user not configured")
    (let ((result (workbench-cc--shell-or-error
                   nil "jira" "issue" "list"
                   "-p" workbench-cc--jira-project
                   "-a" workbench-cc--jira-user
                   "-s" "Done"
                   "--plain" "--no-headers"
                   "--columns" "KEY,SUMMARY")))
      (if (eq :error (car result))
          result
        (let ((output (cadr result)))
          (if (string-empty-p output)
              '()
            (seq-take
             (mapcar (lambda (line)
                       (let ((parts (split-string line "\t+" nil)))
                         (list :key (string-trim (or (nth 0 parts) ""))
                               :summary (string-trim (or (nth 1 parts) "")))))
                     (split-string output "\n" t))
             3)))))))

(defun workbench-cc--jira-next ()
  "Fetch Next queue tickets (top 3). Returns list of plists, or (:error REASON)."
  (if (not workbench-cc--jira-project)
      (list :error "Jira project not configured")
    (let ((result (workbench-cc--shell-or-error
                   nil "jira" "issue" "list"
                   "-p" workbench-cc--jira-project
                   "-s" "Next"
                   "--plain" "--no-headers"
                   "--columns" "KEY,SUMMARY,TYPE")))
      (if (eq :error (car result))
          result
        (let ((output (cadr result)))
          (if (string-empty-p output)
              '()
            (seq-take
             (mapcar (lambda (line)
                       (let ((parts (split-string line "\t+" nil)))
                         (list :key (string-trim (or (nth 0 parts) ""))
                               :summary (string-trim (or (nth 1 parts) ""))
                               :type (string-trim (or (nth 2 parts) "")))))
                     (split-string output "\n" t))
             3)))))))

;;; ── Collect All (IC view) ──────────────────────────────────────────────────

(defun workbench-cc--collect-all ()
  "Collect all dashboard data. Returns plist.
Jira fields may contain (:error REASON) instead of a list when fetch fails."
  (let* ((tickets-raw (workbench-cc--jira-tickets))
         (tickets (if (workbench-cc--error-p tickets-raw)
                      tickets-raw
                    (mapcar (lambda (tkt)
                              (let* ((key (plist-get tkt :key))
                                     (details (workbench-cc--ticket-details key))
                                     (days (workbench-cc--days-since-update (plist-get tkt :updated))))
                                (append tkt
                                        (list :logged-today
                                              (workbench-cc--ticket-commented-today-p key)
                                              :days-stale days
                                              :parent (plist-get details :parent)
                                              :comment (plist-get details :comment)))))
                            tickets-raw))))
    (list :tickets tickets
          :done (workbench-cc--jira-done)
          :next (workbench-cc--jira-next)
          :repos (mapcar #'workbench-cc--repo-status (workbench-cc--recent-repos))
          :commits (workbench-cc--recent-commits)
          :infra (workbench-cc--infra-status)
          :time (format-time-string "%A %d %B, %H:%M"))))

;;; ── Team Lead Data Collection ───────────────────────────────────────────────

(defun workbench-cc--team-tickets-by-status (status)
  "Fetch team tickets in STATUS via JQL. Returns list of plists, or (:error REASON)."
  (if (not (and workbench-cc--jira-project workbench-cc--team-id))
      (list :error "Jira project/team not configured")
    (let* ((jql (format "project = %s AND team = \"%s\" AND status = \"%s\""
                        workbench-cc--jira-project workbench-cc--team-id status))
           (result (workbench-cc--shell-or-error
                    nil "jira" "issue" "list"
                    "--jql" jql
                    "--plain" "--no-headers"
                    "--columns" "KEY,SUMMARY,ASSIGNEE,UPDATED")))
      (if (eq :error (car result))
          result
        (let ((output (cadr result)))
          (if (string-empty-p output)
              '()
            (mapcar (lambda (line)
                      (let ((parts (split-string line "\t+" nil)))
                        (list :key (string-trim (or (nth 0 parts) ""))
                              :summary (string-trim (or (nth 1 parts) ""))
                              :assignee (string-trim (or (nth 2 parts) ""))
                              :updated (string-trim (or (nth 3 parts) "")))))
                    (split-string output "\n" t))))))))

(defun workbench-cc--team-ticket-last-comment (key)
  "Get last comment snippet and author for KEY."
  (when-let ((output (workbench-cc--shell
                      nil "jira" "issue" "view" key "--comments" "1" "--plain")))
    (let ((author nil) (snippet nil))
      (when (string-match "\\([A-Za-z ]+\\) •.*• Latest comment" output)
        (setq author (string-trim (match-string 1 output))))
      (when (string-match "Latest comment[^\n]*\n\\(?:\\s-*\n\\)*\\s-*\\(.+\\)" output)
        (setq snippet (string-trim (match-string 1 output))))
      (list :author author :snippet snippet))))

(defun workbench-cc--team-attention-items (tickets)
  "Compute attention items from TICKETS (In Progress list).
Returns items sorted by urgency: stale first, then no-recent-comment."
  (let ((items nil))
    (dolist (tkt tickets)
      (let* ((days (workbench-cc--days-since-update (plist-get tkt :updated)))
             (key (plist-get tkt :key))
             (assignee (plist-get tkt :assignee)))
        (cond
         ((and days (> days 14))
          (push (list :key key :assignee assignee :days days
                      :reason "two-week rule") items))
         ((and days (> days 7))
          (push (list :key key :assignee assignee :days days
                      :reason "no update 7+ days") items))
         ((and days (> days 3))
          (push (list :key key :assignee assignee :days days
                      :reason "may need check-in") items)))))
    (sort items (lambda (a b)
                  (> (or (plist-get a :days) 0)
                     (or (plist-get b :days) 0))))))

(defun workbench-cc--collect-team-lead ()
  "Collect all data for the team lead command centre view.
Ticket fields may contain (:error REASON) instead of a list when fetch fails."
  (let* ((wip-raw (workbench-cc--team-tickets-by-status workbench-cc--team-status-wip))
         (wip (if (workbench-cc--error-p wip-raw)
                  wip-raw
                (mapcar (lambda (tkt)
                          (let* ((key (plist-get tkt :key))
                                 (comment (workbench-cc--team-ticket-last-comment key)))
                            (append tkt
                                    (list :comment-author (plist-get comment :author)
                                          :comment-snippet (plist-get comment :snippet)))))
                        wip-raw)))
         (next (workbench-cc--team-tickets-by-status workbench-cc--team-status-next))
         (done-raw (workbench-cc--team-tickets-by-status workbench-cc--team-status-done))
         (done (if (workbench-cc--error-p done-raw) done-raw (seq-take done-raw 5)))
         (attention (if (workbench-cc--error-p wip)
                        nil
                      (workbench-cc--team-attention-items wip))))
    (list :wip wip
          :next next
          :done done
          :attention attention
          :infra (workbench-cc--infra-status)
          :time (format-time-string "%A %d %B, %H:%M"))))
