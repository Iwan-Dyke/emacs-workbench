;;; workflows/command-centre-data.el -*- lexical-binding: t; -*-

;; Data collection for the command centre: git/repo status, infra checks,
;; team data collection. Jira data comes from modules/tools/jira.el (ADR 0064).

;;; ── Compatibility aliases ──────────────────────────────────────────────────
;; The command centre SVG and team renderers reference these names.
;; They now delegate to the shared Jira module.

(defvaralias 'workbench-cc--jira-project 'workbench-jira-project)
(defvaralias 'workbench-cc--jira-user 'workbench-jira-user)
(defvaralias 'workbench-cc--git-author 'workbench-jira-git-author)
(defvaralias 'workbench-cc--code-root 'workbench-jira-code-root)
(defvaralias 'workbench-cc--spark-url 'workbench-jira-spark-url)
(defvaralias 'workbench-cc--team-name 'workbench-jira-team-name)
(defvaralias 'workbench-cc--team-id 'workbench-jira-team-id)
(defvaralias 'workbench-cc--team-wip-limit 'workbench-jira-team-wip-limit)
(defvaralias 'workbench-cc--team-members 'workbench-jira-team-members)
(defvaralias 'workbench-cc--team-status-next 'workbench-jira-status-next)
(defvaralias 'workbench-cc--team-status-wip 'workbench-jira-status-wip)
(defvaralias 'workbench-cc--team-status-done 'workbench-jira-status-done)

;;; ── Shell Helpers (for non-Jira data: git, infra) ──────────────────────────

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

;;; ── Jira (delegated to shared module) ──────────────────────────────────────

(defalias 'workbench-cc--error-p #'workbench-jira-error-p)
(defalias 'workbench-cc--error-reason #'workbench-jira-error-reason)
(defalias 'workbench-cc--days-since-update #'workbench-jira-days-since-update)

(defun workbench-cc--jira-tickets ()
  "Fetch In Progress tickets via shared Jira module."
  (workbench-jira--fetch-tickets))

(defun workbench-cc--ticket-details (key)
  "Get extra details for KEY via shared Jira module."
  (workbench-jira--ticket-details key))

(defun workbench-cc--ticket-commented-today-p (key)
  "Return t if KEY has a comment from today."
  (workbench-jira--ticket-commented-today-p key))

(defun workbench-cc--ticket-last-comment-date (key)
  "Get date of last comment on KEY."
  (workbench-jira--ticket-last-comment-date key))

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

;;; ── Jira Done / Next (delegated) ────────────────────────────────────────────

(defun workbench-cc--jira-done ()
  "Fetch recently Done tickets via shared Jira module."
  (workbench-jira--fetch-done))

(defun workbench-cc--jira-next ()
  "Fetch Next queue tickets via shared Jira module."
  (workbench-jira--fetch-next))

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
  "Fetch team tickets in STATUS via shared Jira module."
  (workbench-jira--fetch-team-by-status status))

(defun workbench-cc--team-ticket-last-comment (key)
  "Get last comment snippet and author for KEY."
  (workbench-jira--team-ticket-last-comment key))

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
