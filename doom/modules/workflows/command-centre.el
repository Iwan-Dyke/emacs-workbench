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
  (let* ((data-file (expand-file-name
                     "modules/workflows/command-centre-data.el"
                     doom-user-dir))
         (view workbench/command-centre-view)
         ;; Build an elisp form that loads the data module with all config,
         ;; runs the collection, and prints the result as a sexp.
         (form `(progn
                  ;; Set config variables before loading
                  (setq workbench-cc--jira-project ,workbench-cc--jira-project
                        workbench-cc--jira-user ,workbench-cc--jira-user
                        workbench-cc--git-author ,workbench-cc--git-author
                        workbench-cc--code-root ,workbench-cc--code-root
                        workbench-cc--spark-url ,workbench-cc--spark-url
                        workbench-cc--team-name ,workbench-cc--team-name
                        workbench-cc--team-id ,workbench-cc--team-id
                        workbench-cc--team-wip-limit ,workbench-cc--team-wip-limit
                        workbench-cc--team-members ',workbench-cc--team-members
                        workbench-cc--team-status-next ,workbench-cc--team-status-next
                        workbench-cc--team-status-wip ,workbench-cc--team-status-wip
                        workbench-cc--team-status-done ,workbench-cc--team-status-done)
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
    (run-at-time 60 nil
                 (lambda ()
                   (when (and (process-live-p proc)
                              (eq workbench-cc--async-process proc))
                     (message "Command centre: fetch timed out after 60s")
                     (delete-process proc))))))

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
    ;; First open — use sync so the buffer appears immediately
    (workbench-cc-refresh-sync)
    (when-let ((buf (get-buffer workbench-cc--buffer-name)))
      (switch-to-buffer buf)
      (workbench-cc-mode)))
  (unless workbench-cc--timer
    (setq workbench-cc--timer
          (run-at-time 300 300 #'workbench-cc--maybe-refresh))))

(defun workbench-cc--startup ()
  "Show command centre on startup (work profile only).
Suppresses Doom's dashboard immediately but defers SVG rendering to the first
graphic frame, since `face-attribute' returns `unspecified' in a headless daemon."
  (when (string= workbench/profile "work")
    (setq +doom-dashboard-functions nil)
    (add-hook 'server-after-make-frame-hook #'workbench-cc--show-on-frame)))

(defun workbench-cc--show-on-frame ()
  "Render and show the command centre in the new frame."
  (remove-hook 'server-after-make-frame-hook #'workbench-cc--show-on-frame)
  (workbench-cc-refresh-sync)
  (when-let ((buf (get-buffer workbench-cc--buffer-name)))
    (switch-to-buffer buf)
    (workbench-cc-mode)))

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
