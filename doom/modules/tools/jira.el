;;; tools/jira.el -*- lexical-binding: t; -*-

;; Shared Jira fetch module (ADR 0064).
;; Provides config variables, shell helpers, data fetching with caching,
;; and a single refresh timer. Both command centre and org consume this.

(require 'seq)

;;; ── Config ─────────────────────────────────────────────────────────────────

(defvar workbench-jira-project nil
  "Jira project key. Set in profiles/local.el.")
(defvar workbench-jira-user nil
  "Jira username (email). Set in profiles/local.el.")
(defvar workbench-jira-git-author nil
  "Git author name fragment for filtering commits. Set in profiles/local.el.")
(defvar workbench-jira-code-root "~/code/"
  "Root directory to scan for git repositories.")
(defvar workbench-jira-spark-url "http://localhost:8888"
  "URL to health-check the local Spark environment.")

;; Board config
(defvar workbench-jira-wip-limit 9
  "Total board WIP limit (all teams combined).")

;; Team config
(defvar workbench-jira-team-name nil
  "Team display name. Set in profiles/local.el.")
(defvar workbench-jira-team-id nil
  "Jira team UUID for JQL filtering. Set in profiles/local.el.")
(defvar workbench-jira-team-wip-limit 2
  "WIP limit for the team.")
(defvar workbench-jira-team-members nil
  "List of team member display names. Set in profiles/local.el.")

;; Status names
(defvar workbench-jira-status-next "Next"
  "Status name for the team's 'next up' column.")
(defvar workbench-jira-status-wip "In Progress"
  "Status name for the team's active work column.")
(defvar workbench-jira-status-done "Done"
  "Status name for the team's completed column.")

;; Cache TTL
(defvar workbench-jira-refresh-interval 300
  "Seconds between automatic Jira data refreshes (default 5 minutes).")

;;; ── Shell Helpers ──────────────────────────────────────────────────────────

(defalias 'workbench-jira--shell #'workbench-shell)
(defalias 'workbench-jira--shell-lines #'workbench-shell-lines)
(defalias 'workbench-jira--shell-or-error #'workbench-shell-or-error)

;;; ── Error helpers ──────────────────────────────────────────────────────────

(defun workbench-jira-error-p (result)
  "Return non-nil if RESULT is an error plist from a fetch function."
  (and (consp result) (eq :error (car result))))

(defun workbench-jira-error-reason (result)
  "Return the error reason string from RESULT."
  (cadr result))

;;; ── Fetch Functions ────────────────────────────────────────────────────────

(defun workbench-jira--fetch-tickets ()
  "Fetch In Progress tickets. Returns list of plists, or (:error REASON)."
  (if (not (and workbench-jira-project workbench-jira-user))
      (list :error "Jira project/user not configured")
    (let ((result (workbench-jira--shell-or-error
                   nil "jira" "issue" "list"
                   "-p" workbench-jira-project
                   "-a" workbench-jira-user
                   "-s" workbench-jira-status-wip
                   "--plain" "--no-headers"
                   "--columns" "KEY,SUMMARY,TYPE,UPDATED")))
      (if (eq :error (car result))
          result
        (let ((output (cadr result)))
          (if (string-empty-p output)
              '()
            (mapcar (lambda (line)
                      (let ((parts (split-string line "\t")))
                        (list :key (string-trim (or (nth 0 parts) ""))
                              :summary (string-trim (or (nth 1 parts) ""))
                              :type (string-trim (or (nth 2 parts) ""))
                              :updated (string-trim (or (nth 3 parts) "")))))
                    (split-string output "\n" t))))))))

(defun workbench-jira--fetch-done ()
  "Fetch recently Done tickets (last 3). Returns list of plists, or (:error REASON)."
  (if (not (and workbench-jira-project workbench-jira-user))
      (list :error "Jira project/user not configured")
    (let ((result (workbench-jira--shell-or-error
                   nil "jira" "issue" "list"
                   "-p" workbench-jira-project
                   "-a" workbench-jira-user
                   "-s" workbench-jira-status-done
                   "--plain" "--no-headers"
                   "--columns" "KEY,SUMMARY")))
      (if (eq :error (car result))
          result
        (let ((output (cadr result)))
          (if (string-empty-p output)
              '()
            (seq-take
             (mapcar (lambda (line)
                       (let ((parts (split-string line "\t")))
                         (list :key (string-trim (or (nth 0 parts) ""))
                               :summary (string-trim (or (nth 1 parts) "")))))
                     (split-string output "\n" t))
             3)))))))

(defun workbench-jira--fetch-next ()
  "Fetch Next queue tickets (top 3). Returns list of plists, or (:error REASON)."
  (if (not workbench-jira-project)
      (list :error "Jira project not configured")
    (let ((result (workbench-jira--shell-or-error
                   nil "jira" "issue" "list"
                   "-p" workbench-jira-project
                   "-s" workbench-jira-status-next
                   "--plain" "--no-headers"
                   "--columns" "KEY,SUMMARY,TYPE")))
      (if (eq :error (car result))
          result
        (let ((output (cadr result)))
          (if (string-empty-p output)
              '()
            (seq-take
             (mapcar (lambda (line)
                       (let ((parts (split-string line "\t")))
                         (list :key (string-trim (or (nth 0 parts) ""))
                               :summary (string-trim (or (nth 1 parts) ""))
                               :type (string-trim (or (nth 2 parts) "")))))
                     (split-string output "\n" t))
             3)))))))

(defun workbench-jira--fetch-team-by-status (status)
  "Fetch team tickets in STATUS via JQL. Returns list of plists, or (:error REASON)."
  (if (not (and workbench-jira-project workbench-jira-team-id))
      (list :error "Jira project/team not configured")
    (let* ((jql (format "project = \"%s\" AND team = \"%s\" AND status = \"%s\""
                        workbench-jira-project workbench-jira-team-id status))
           (result (workbench-jira--shell-or-error
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
                      (let ((parts (split-string line "\t")))
                        (list :key (string-trim (or (nth 0 parts) ""))
                              :summary (string-trim (or (nth 1 parts) ""))
                              :assignee (string-trim (or (nth 2 parts) ""))
                              :updated (string-trim (or (nth 3 parts) "")))))
                    (split-string output "\n" t))))))))

(defun workbench-jira--ticket-details (key)
  "Get extra details for KEY: last comment snippet and parent."
  (when-let ((output (workbench-jira--shell
                      nil "jira" "issue" "view" key "--comments" "1" "--plain")))
    (let ((parent nil) (comment nil))
      (when (string-match "Parent:\\s-*\\([A-Z]+-[0-9]+\\)" output)
        (setq parent (match-string 1 output)))
      (when (string-match "Latest comment[^\n]*\n\\(?:\\s-*\n\\)*\\s-*\\(.+\\)" output)
        (setq comment (string-trim (match-string 1 output))))
      (list :parent parent :comment comment))))

(defun workbench-jira--ticket-last-comment-date (key)
  "Get date of last comment on KEY, or nil."
  (when-let ((output (workbench-jira--shell
                      nil "jira" "issue" "view" key "--plain")))
    (when (string-match "• \\([A-Z][a-z]+, [0-9]+ [A-Z][a-z]+ [0-9]+\\) •" output)
      (match-string 1 output))))

(defun workbench-jira--ticket-commented-today-p (key)
  "Return t if KEY has a comment from today."
  (when-let ((date-str (workbench-jira--ticket-last-comment-date key)))
    (let ((today (format-time-string "%d %b %Y")))
      (string-match-p (regexp-quote today) date-str))))

(defun workbench-jira--team-ticket-last-comment (key)
  "Get last comment snippet and author for KEY."
  (when-let ((output (workbench-jira--shell
                      nil "jira" "issue" "view" key "--comments" "1" "--plain")))
    (let ((author nil) (snippet nil))
      (when (string-match "\\([A-Za-z ]+\\) •.*• Latest comment" output)
        (setq author (string-trim (match-string 1 output))))
      (when (string-match "Latest comment[^\n]*\n\\(?:\\s-*\n\\)*\\s-*\\(.+\\)" output)
        (setq snippet (string-trim (match-string 1 output))))
      (list :author author :snippet snippet))))

(defun workbench-jira-days-since-update (updated-str)
  "Return days since UPDATED-STR, or nil if unparseable.
Limitation: only absolute date formats (ISO 8601, RFC 2822, etc.) are supported.
Relative date strings like \"2 hours ago\" or \"3 days ago\" that jira-cli may
output will return nil.  Configure jira-cli to use ISO date output
\(e.g. `jira config set output.date iso-8601`) to ensure correct parsing."
  (condition-case nil
      (let* ((time (date-to-time updated-str))
             (diff (time-subtract (current-time) time)))
        (/ (float-time diff) 86400.0))
    (error nil)))

;;; ── Cache ──────────────────────────────────────────────────────────────────

(defvar workbench-jira--cache nil
  "Cached Jira data plist. Populated by `workbench-jira-refresh'.")

(defvar workbench-jira--cache-time nil
  "Time when `workbench-jira--cache' was last populated.")

(defvar workbench-jira--timer nil
  "Timer for automatic Jira refresh.")

(defvar workbench-jira-after-refresh-hook nil
  "Hook run after Jira data is refreshed. Called with no arguments.
Consumers (command centre, org) add functions here to react to new data.")

(defvar workbench-jira-external-refresh-p nil
  "When non-nil, the Jira module defers to an external refresh owner (e.g. command centre).
The auto-refresh timer will not start.")

(defun workbench-jira-cache ()
  "Return the current Jira cache plist, or nil if not yet populated."
  workbench-jira--cache)

(defun workbench-jira-cache-tickets ()
  "Return cached In Progress tickets (list of plists), or nil."
  (plist-get workbench-jira--cache :tickets))

(defun workbench-jira-cache-fresh-p ()
  "Return non-nil if the cache is within the refresh interval."
  (and workbench-jira--cache-time
       (< (float-time (time-subtract (current-time) workbench-jira--cache-time))
          workbench-jira-refresh-interval)))

(defun workbench-jira-set-cache (tickets done next)
  "Update the shared Jira cache with TICKETS, DONE, and NEXT data.
Sets the cache timestamp and runs `workbench-jira-after-refresh-hook'."
  (setq workbench-jira--cache (list :tickets tickets :done done :next next))
  (setq workbench-jira--cache-time (current-time))
  (run-hooks 'workbench-jira-after-refresh-hook))

(defun workbench-jira-refresh-sync ()
  "Refresh the Jira cache synchronously and run hooks.
Use this for callers that need blocking behaviour (e.g. first-call cache population).
Accepts partial results — only stores keys that succeeded."
  (interactive)
  (let* ((tickets (workbench-jira--fetch-tickets))
         (done (workbench-jira--fetch-done))
         (next (workbench-jira--fetch-next))
         (result (list :tickets (if (workbench-jira-error-p tickets)
                                    (plist-get workbench-jira--cache :tickets)
                                  tickets)
                       :done (if (workbench-jira-error-p done)
                                 (plist-get workbench-jira--cache :done)
                               done)
                       :next (if (workbench-jira-error-p next)
                                 (plist-get workbench-jira--cache :next)
                               next))))
    ;; Update cache if at least one fetch succeeded
    (when (or (not (workbench-jira-error-p tickets))
              (not (workbench-jira-error-p done))
              (not (workbench-jira-error-p next)))
      (setq workbench-jira--cache result)
      (setq workbench-jira--cache-time (current-time))
      (run-hooks 'workbench-jira-after-refresh-hook))))

(defun workbench-jira-refresh ()
  "Refresh the Jira cache asynchronously and run hooks when done.
Spawns a child Emacs (batch) via `workbench-async-eval' that runs the
three fetch calls and returns the result as a plist."
  (interactive)
  (let* ((shell-file (expand-file-name "modules/tools/shell.el" doom-user-dir))
         (jira-file (expand-file-name "modules/tools/jira.el" doom-user-dir))
         (form `(progn
                  (load ,shell-file nil t)
                  (setq workbench-jira-project ,workbench-jira-project
                        workbench-jira-user ,workbench-jira-user
                        workbench-jira-git-author ,workbench-jira-git-author
                        workbench-jira-code-root ,workbench-jira-code-root
                        workbench-jira-spark-url ,workbench-jira-spark-url
                        workbench-jira-team-name ,workbench-jira-team-name
                        workbench-jira-team-id ,workbench-jira-team-id
                        workbench-jira-team-wip-limit ,workbench-jira-team-wip-limit
                        workbench-jira-team-members ',workbench-jira-team-members
                        workbench-jira-status-next ,workbench-jira-status-next
                        workbench-jira-status-wip ,workbench-jira-status-wip
                        workbench-jira-status-done ,workbench-jira-status-done)
                  (load ,jira-file nil t)
                  (let ((result (list :tickets (workbench-jira--fetch-tickets)
                                      :done (workbench-jira--fetch-done)
                                      :next (workbench-jira--fetch-next))))
                    (prin1 result)))))
    (workbench-async-eval
     'jira form
     (lambda (result)
       (when result
         (let ((merged (list :tickets (if (workbench-jira-error-p (plist-get result :tickets))
                                         (plist-get workbench-jira--cache :tickets)
                                       (plist-get result :tickets))
                             :done (if (workbench-jira-error-p (plist-get result :done))
                                       (plist-get workbench-jira--cache :done)
                                     (plist-get result :done))
                             :next (if (workbench-jira-error-p (plist-get result :next))
                                       (plist-get workbench-jira--cache :next)
                                     (plist-get result :next)))))
           (setq workbench-jira--cache merged))
         (setq workbench-jira--cache-time (current-time))
         (run-hooks 'workbench-jira-after-refresh-hook)))
     60 "Jira refresh")))

(defun workbench-jira-ensure-cache ()
  "Ensure the cache is populated. Refreshes synchronously if stale or empty."
  (unless (workbench-jira-cache-fresh-p)
    (workbench-jira-refresh-sync)))

(defun workbench-jira--maybe-refresh ()
  "Refresh if Emacs is not in the middle of user input."
  (unless (input-pending-p)
    (workbench-jira-refresh)))

(defun workbench-jira-start-timer ()
  "Start the automatic refresh timer."
  (interactive)
  (workbench-jira-stop-timer)
  (setq workbench-jira--timer
        (run-at-time workbench-jira-refresh-interval
                     workbench-jira-refresh-interval
                     #'workbench-jira--maybe-refresh)))

(defun workbench-jira-stop-timer ()
  "Stop the automatic refresh timer."
  (interactive)
  (when workbench-jira--timer
    (cancel-timer workbench-jira--timer)
    (setq workbench-jira--timer nil)))

(defun workbench-jira--maybe-start-timer ()
  "Start the Jira refresh timer if project and user are configured and no external owner."
  (when (and workbench-jira-project workbench-jira-user
             (not workbench-jira-external-refresh-p))
    (workbench-jira-start-timer)))

;; Start the timer when Jira is configured
(add-hook 'doom-init-ui-hook #'workbench-jira--maybe-start-timer)

(provide 'workbench-jira)
