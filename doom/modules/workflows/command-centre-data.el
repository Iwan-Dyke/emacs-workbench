;;; workflows/command-centre-data.el -*- lexical-binding: t; -*-

;; Data collection for the command centre: git/repo status, infra checks,
;; team data collection. Jira data comes from modules/tools/jira.el (ADR 0064).

(require 'seq)

;;; ── Jira (delegated to shared module) ──────────────────────────────────────

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
  (let* ((dirs (directory-files (expand-file-name workbench-jira-code-root) t "^[^.]" t))
         (git-dirs (seq-filter (lambda (d)
                                 (file-directory-p (expand-file-name ".git" d)))
                               dirs))
         (with-commit (seq-filter #'identity
                        (mapcar (lambda (d)
                                  (when-let ((date (workbench-shell
                                                    d "git" "log" "-1"
                                                    (concat "--author=" workbench-jira-git-author) "--format=%ct")))
                                    (cons d (string-to-number date))))
                                git-dirs)))
         (sorted (sort with-commit (lambda (a b) (> (cdr a) (cdr b))))))
    (seq-take (mapcar #'car sorted) 5)))

(defun workbench-cc--repo-status (dir)
  "Get git status plist for DIR."
  (let ((branch (workbench-shell dir "git" "branch" "--show-current"))
        (dirty (workbench-shell-lines dir "git" "status" "--porcelain"))
        (ab (workbench-shell dir "git" "rev-list" "--left-right" "--count" "HEAD...@{upstream}"))
        (last-commit (workbench-shell dir "git" "log" "-1" (concat "--author=" workbench-jira-git-author) "--format=%ar"))
        (last-msg (workbench-shell dir "git" "log" "-1" (concat "--author=" workbench-jira-git-author) "--format=%s")))
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
      (when-let ((lines (workbench-shell-lines
                         dir "git" "log" "-5"
                         (concat "--author=" workbench-jira-git-author) "--since=3 days ago"
                         "--format=%ct|%ar|%s")))
        (dolist (line lines)
          ;; Split on only the first two pipes — the message may contain pipes
          (when (string-match "\\([^|]+\\)|\\([^|]+\\)|\\(.*\\)" line)
            (push (list :epoch (string-to-number (match-string 1 line))
                        :repo (file-name-nondirectory dir)
                        :time (match-string 2 line)
                        :msg (match-string 3 line))
                  all)))))
    (seq-take (sort all (lambda (a b)
                          (> (plist-get a :epoch) (plist-get b :epoch))))
              5)))

;;; ── Infrastructure ─────────────────────────────────────────────────────────

(defun workbench-cc--infra-status ()
  "Check infrastructure health."
  (list :colima (not (null (workbench-shell nil "colima" "status")))
        :containers (or (workbench-shell-lines
                         nil "docker" "ps" "--format" "{{.Names}}")
                        '())
        :spark (condition-case nil
                   (eq 0 (call-process "curl" nil nil nil
                                       "-s" "-o" "/dev/null"
                                       "-w" "" "--max-time" "1"
                                       workbench-jira-spark-url))
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
         (tickets (if (workbench-jira-error-p tickets-raw)
                      tickets-raw
                    (mapcar (lambda (tkt)
                              (let* ((key (plist-get tkt :key))
                                     (details (workbench-cc--ticket-details key))
                                     (days (workbench-jira-days-since-update (plist-get tkt :updated))))
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
      (let* ((days (workbench-jira-days-since-update (plist-get tkt :updated)))
             (key (plist-get tkt :key))
             (assignee (plist-get tkt :assignee)))
        (cond
         ;; Nil days means unparseable date (e.g. "2 hours ago") — recently
         ;; updated, so skip without flagging.
         ((null days) nil)
         ((> days 14)
          (push (list :key key :assignee assignee :days days
                      :reason "two-week rule") items))
         ((> days 7)
          (push (list :key key :assignee assignee :days days
                      :reason "no update 7+ days") items))
         ((> days 3)
          (push (list :key key :assignee assignee :days days
                      :reason "may need check-in") items)))))
    (sort items (lambda (a b)
                  (> (or (plist-get a :days) 0)
                     (or (plist-get b :days) 0))))))

(defun workbench-cc--collect-team-lead ()
  "Collect all data for the team lead command centre view.
Ticket fields may contain (:error REASON) instead of a list when fetch fails.
Also fetches personal In Progress tickets (via :tickets) so the shared Jira
cache can be populated for org agenda sync."
  (let* ((wip-raw (workbench-cc--team-tickets-by-status workbench-jira-status-wip))
         (wip (if (workbench-jira-error-p wip-raw)
                  wip-raw
                (mapcar (lambda (tkt)
                          (let* ((key (plist-get tkt :key))
                                 (comment (workbench-cc--team-ticket-last-comment key)))
                            (append tkt
                                    (list :comment-author (plist-get comment :author)
                                          :comment-snippet (plist-get comment :snippet)))))
                        wip-raw)))
         (next (workbench-cc--team-tickets-by-status workbench-jira-status-next))
         (done-raw (workbench-cc--team-tickets-by-status workbench-jira-status-done))
         (done (if (workbench-jira-error-p done-raw) done-raw (seq-take done-raw 5)))
         (attention (if (workbench-jira-error-p wip)
                        nil
                      (workbench-cc--team-attention-items wip)))
         ;; Also fetch personal tickets for the shared Jira cache (org agenda)
         (personal-tickets (workbench-cc--jira-tickets)))
    (list :wip wip
          :next next
          :done done
          :tickets personal-tickets
          :attention attention
          :infra (workbench-cc--infra-status)
          :time (format-time-string "%A %d %B, %H:%M"))))
