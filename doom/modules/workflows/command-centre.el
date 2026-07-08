;;; workflows/command-centre.el -*- lexical-binding: t; -*-

;; SVG command centre dashboard replacing the Doom dashboard (work profile only).
;; Shows: Jira tickets, git repo status, recent commits, infrastructure health.
;; ADR 0058.

(load! "command-centre-data")
(load! "command-centre-svg")
(load! "command-centre-team")

;;; ── Lifecycle ──────────────────────────────────────────────────────────────

(defvar workbench-cc--buffer-name "*command-centre*")
(defvar workbench-cc--timer nil "Auto-refresh timer.")
(defvar workbench-cc--data nil "Cached dashboard data.")
(defvar workbench-cc--async-process nil "Current async fetch process, or nil.")
(defvar workbench-cc--async-timeout nil "Timeout timer for the current async fetch.")

(defun workbench-cc--render-current ()
  "Render the current cached data without refetching."
  (when workbench-cc--data
    (pcase workbench/command-centre-view
      ('team-lead (workbench-cc--render-team-lead workbench-cc--data))
      (_ (workbench-cc--render workbench-cc--data)))))

(defun workbench-cc--async-collect (callback)
  "Run data collection asynchronously, calling CALLBACK with the result plist.
Spawns a child Emacs that loads the data module and runs the appropriate
collect function. CALLBACK receives the parsed plist on success, or nil on
failure. Kills the child process after 60 seconds if it hangs."
  ;; Kill any in-flight fetch
  (when (and workbench-cc--async-process
             (process-live-p workbench-cc--async-process))
    (delete-process workbench-cc--async-process))
  (when (timerp workbench-cc--async-timeout)
    (cancel-timer workbench-cc--async-timeout)
    (setq workbench-cc--async-timeout nil))
  (let* ((jira-file (expand-file-name
                     "modules/tools/jira.el"
                     doom-user-dir))
         (data-file (expand-file-name
                     "modules/workflows/command-centre-data.el"
                     doom-user-dir))
         (view workbench/command-centre-view)
         ;; Build an elisp form that loads the jira + data modules with all
         ;; config, runs the collection, and prints the result as a sexp.
         (form `(progn
                  ;; Set config variables before loading
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
                  (load ,data-file nil t)
                  (let ((result ,(pcase view
                                   ('team-lead '(workbench-cc--collect-team-lead))
                                   (_ '(workbench-cc--collect-all)))))
                    (prin1 result))))
         (emacs-bin (expand-file-name invocation-name invocation-directory))
         (output-buf (generate-new-buffer " *cc-async*"))
         (proc (make-process
                :name "command-centre-fetch"
                :buffer output-buf
                :command (list emacs-bin "--batch" "--eval" (prin1-to-string form))
                :noquery t
                :sentinel
                (lambda (process _event)
                  (when (memq (process-status process) '(exit signal))
                    ;; Cancel the timeout timer — process finished.
                    (when (timerp workbench-cc--async-timeout)
                      (cancel-timer workbench-cc--async-timeout)
                      (setq workbench-cc--async-timeout nil))
                    (let ((result nil))
                      (if (zerop (process-exit-status process))
                          (with-current-buffer (process-buffer process)
                            (goto-char (point-min))
                            (condition-case nil
                                (setq result (read (current-buffer)))
                              (error
                               (message "Command centre: failed to parse fetch result"))))
                        (message "Command centre: fetch process exited %d"
                                 (process-exit-status process)))
                      (kill-buffer (process-buffer process))
                      (when (eq workbench-cc--async-process process)
                        (setq workbench-cc--async-process nil))
                      (funcall callback result)))))))
    (setq workbench-cc--async-process proc)
    ;; Timeout: kill after 60s if still running
    (setq workbench-cc--async-timeout
          (run-at-time 60 nil
                       (lambda ()
                         (when (and (process-live-p proc)
                                    (eq workbench-cc--async-process proc))
                           (message "Command centre: fetch timed out after 60s")
                           (delete-process proc)))))))

(defun workbench-cc-refresh ()
  "Refetch data asynchronously and refresh the command centre dashboard."
  (interactive)
  (message "Command centre: fetching...")
  (workbench-cc--async-collect
   (lambda (data)
     (when data
       (setq workbench-cc--data data)
       (workbench-cc--render-current)
       (message "Command centre: refreshed")))))

(defun workbench-cc-refresh-sync ()
  "Refetch data synchronously (blocking). Use for startup or debugging."
  (interactive)
  (message "Command centre: fetching data...")
  (setq workbench-cc--data
        (pcase workbench/command-centre-view
          ('team-lead (workbench-cc--collect-team-lead))
          (_ (workbench-cc--collect-all))))
  (workbench-cc--render-current)
  (message "Command centre: refreshed"))

(defun workbench-cc-redraw ()
  "Redraw the command centre from cached data (instant)."
  (interactive)
  (if workbench-cc--data
      (workbench-cc--render-current)
    (workbench-cc-refresh)))

(defun workbench-cc--maybe-refresh (&rest _)
  "Refresh if the command centre buffer is visible."
  (when (get-buffer-window workbench-cc--buffer-name)
    (workbench-cc-refresh)))

(defvar workbench-cc-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "r" #'workbench-cc-redraw)
    (define-key map "R" #'workbench-cc-refresh)
    (define-key map (kbd "RET") #'workbench-cc--open-ticket-at-point)
    (define-key map "q" #'quit-window)
    map))

(define-derived-mode workbench-cc-mode special-mode "CommandCentre"
  "Mode for the workbench command centre."
  (setq-local cursor-type nil)
  (setq-local truncate-lines t)
  (setq-local buffer-read-only t))

(after! evil
  (evil-define-key 'normal workbench-cc-mode-map
    "r" #'workbench-cc-redraw
    "R" #'workbench-cc-refresh
    (kbd "RET") #'workbench-cc--open-ticket-at-point
    "q" #'quit-window))

(defun workbench-cc-open ()
  "Open the command centre dashboard."
  (interactive)
  (if workbench-cc--data
      (progn
        (workbench-cc--render-current)
        (switch-to-buffer workbench-cc--buffer-name)
        (workbench-cc-mode)
        (workbench-cc-refresh))
    ;; First open — show placeholder and fetch async
    (let ((buf (get-buffer-create workbench-cc--buffer-name)))
      (with-current-buffer buf
        (let ((inhibit-read-only t))
          (erase-buffer)
          (insert "Command centre loading...")))
      (switch-to-buffer buf)
      (workbench-cc-mode))
    (workbench-cc-refresh))
  (unless workbench-cc--timer
    (setq workbench-cc--timer
          (run-at-time 300 300 #'workbench-cc--maybe-refresh))))

(defun workbench-cc--startup ()
  "Show command centre on startup (work profile only).
Suppresses Doom's dashboard immediately but defers SVG rendering until after
startup workspaces have been created. This avoids a race where session.el
switches back to the dashboard workspace and buries the command centre buffer."
  (when (string= workbench/profile "work")
    (setq +dashboard-functions nil
          initial-buffer-choice nil)
    ;; Prevent Doom from reopening the dashboard buffer on workspace switch
    (advice-add '+dashboard-init-h :override #'ignore)
    (if (daemonp)
        ;; Daemon: hook after startup workspaces via an advice that fires once.
        (advice-add 'workbench/open-startup-workspaces :after
                    #'workbench-cc--after-startup-workspaces)
      ;; Non-daemon fallback
      (add-hook 'window-setup-hook #'workbench-cc--show-on-frame))))

(defun workbench-cc--after-startup-workspaces (&rest _)
  "Show the command centre after startup workspaces have been created.
Self-removing — runs once then removes itself."
  (advice-remove 'workbench/open-startup-workspaces
                 #'workbench-cc--after-startup-workspaces)
  (workbench-cc--show-on-frame))

(defun workbench-cc--show-on-frame ()
  "Render and show the command centre in the new frame.
Uses async fetch so the frame is responsive immediately.
Switches to the main (dashboard) workspace first so the command centre
replaces the Doom dashboard rather than appearing in whatever workspace
happens to be current."
  (remove-hook 'server-after-make-frame-hook #'workbench-cc--show-on-frame)
  ;; Ensure we're in the main/dashboard workspace
  (when (fboundp '+workspace-switch)
    (+workspace-switch "main"))
  ;; Kill the Doom dashboard buffer if it's squatting in the window
  (when-let ((doom-buf (get-buffer "*doom*")))
    (when (eq doom-buf (window-buffer))
      (kill-buffer doom-buf)))
  ;; Show a placeholder buffer immediately so the user sees something
  (let ((buf (get-buffer-create workbench-cc--buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (insert "Command centre loading...")))
    (switch-to-buffer buf)
    (workbench-cc-mode))
  ;; Fetch data without blocking
  (workbench-cc-refresh))

;; Run early so it suppresses doom dashboard before it renders
(add-hook 'doom-init-ui-hook #'workbench-cc--startup -90)

;; Redraw on window resize
(defun workbench-cc--on-resize (&optional _frame)
  "Redraw if command centre is visible. Only needed for SVG (IC) view."
  (when (and workbench-cc--data
             (eq workbench/command-centre-view 'ic)
             (get-buffer-window workbench-cc--buffer-name))
    (workbench-cc--render workbench-cc--data)))

(add-hook 'window-size-change-functions #'workbench-cc--on-resize)
