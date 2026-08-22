;;; workflows/session.el -*- lexical-binding: t; -*-

(declare-function workbench/open-files "modules/tools/files")
(declare-function workbench/open-files-full-frame "modules/tools/files")
(declare-function workbench/open-default-ai-workspace "modules/workflows/ai")
(declare-function workbench-repos-refresh "modules/workflows/repos")

;; Session startup: the workspaces a fresh daemon opens, and the persp-mode
;; tweaks that keep them stable. Composes the files browser (tools/files) and
;; the default AI agent (workflows/ai) into the start-of-day layout (ADR 0042,
;; ADR 0049). Future home for fuller session/layout restore (ADR 0013) and the
;; default workspace set (ADR 0038).

;; Start clean each launch (ADR 0013) and keep the daemon's workspaces alive
;; across frame open/close (ADR 0023). By default Doom autosaves the session on
;; kill and tears a frame's workspace down with the frame, which fights the
;; reconnect model and can replay a stale window layout into the just-born (still
;; tiny) frame ("window too small to accommodate state"), corrupting the startup
;; workspaces and deleting the dashboard. Disable both.
(after! persp-mode
  (setq persp-auto-save-opt 0)
  (remove-hook 'delete-frame-functions #'+workspaces-delete-associated-workspace-h)
  (remove-hook 'server-done-hook #'+workspaces-delete-associated-workspace-h))

(defun workbench/open-startup-workspaces ()
  "Open the startup workspaces: agenda, AI agent, and files browser.
Order: dashboard → agenda → ai → files (ADR 0042, ADR 0065).
Leaves the original (dashboard) workspace selected.
Each step is wrapped in condition-case so a failure in one workspace
(e.g. vterm unavailable for AI) doesn't prevent the others from being created."
  (interactive)
  (unless (and (fboundp '+workspace-switch)
               (fboundp '+workspace-current-name))
    (user-error "Doom workspaces are not available"))
  (let ((starting-workspace (+workspace-current-name)))
    ;; Agenda workspace
    (condition-case nil
        (progn
          (+workspace-switch "agenda" t)
          (when (fboundp 'workbench-org/open-agenda)
            (workbench-org/open-agenda)))
      (error nil))
    ;; AI workspace
    (condition-case nil
        (workbench/open-default-ai-workspace)
      (error nil))
    ;; Files workspace
    (condition-case nil
        (progn
          (+workspace-switch "files" t)
          (workbench/open-files))
      (error nil))
    ;; Repos workspace
    (condition-case nil
        (progn
          (+workspace-switch "repos" t)
          (workbench-repos-refresh)
          (switch-to-buffer (get-buffer-create "*repos*"))
          (delete-other-windows))
      (error nil))
    ;; Return to dashboard
    (+workspace-switch starting-workspace t)
    (+workspace/display)))

(defvar workbench--startup-workspaces-opened nil
  "Whether startup workspaces have been opened for this Emacs process.")

(defun workbench--open-startup-workspaces-on-frame (&rest _)
  "Open startup workspaces once persp-mode is active and a graphic frame exists."
  (when (and (not workbench--startup-workspaces-opened)
             (display-graphic-p))
    (condition-case err
        (progn
          (workbench/open-startup-workspaces)
          (setq workbench--startup-workspaces-opened t)
          ;; Remove self from the hook — no longer needed.
          (remove-hook 'server-after-make-frame-hook
                       #'workbench--open-startup-workspaces-on-frame))
      (error
       (message "Workbench startup workspaces failed: %s"
                (error-message-string err))))))

(add-hook! 'persp-mode-hook
  (defun workbench--startup-workspaces-after-persp ()
    "Open startup workspaces after persp-mode initialises."
    (when (and persp-mode (not workbench--startup-workspaces-opened))
      (if (display-graphic-p)
          (workbench--open-startup-workspaces-on-frame)
        ;; Daemon started headless — wait for first frame.
        (add-hook 'server-after-make-frame-hook
                  #'workbench--open-startup-workspaces-on-frame)))))

;; The files workspace shows full-frame Dirvish (listing + preview). Full-frame
;; Dirvish cannot survive persp's window-config save/restore across a workspace
;; switch — it returns as a blank buffer — so rebuild it fresh on every entry
;; rather than persisting it. To make the rebuild seamless, return to the
;; directory and file last browsed. Those are tracked live while you browse
;; (below), not read when leaving: by switch time full-frame Dirvish has already
;; collapsed and killed its index buffer, so the position is no longer readable
;; from window or buffer state.

(defvar workbench--files-directory nil
  "Directory last browsed in the files workspace, restored on re-entry.")

(defvar workbench--files-file nil
  "File at point last in the files workspace, re-selected on re-entry.")

(defun workbench--files-real-dired-p ()
  "Non-nil if the current buffer is a browsable Dired index.
Excludes Dirvish's parent and preview panes, which are also `dired-mode'."
  (and (derived-mode-p 'dired-mode)
       (let ((name (buffer-name)))
         (and (not (string-prefix-p " " name))
              (not (string-match-p "\\*dirvish-" name))))))

(defvar-local workbench--files-track-timer nil
  "Idle timer for debouncing files workspace position tracking.")

(defun workbench--files-track-point ()
  "Schedule position tracking after idle.
Runs from `post-command-hook' in Dired buffers but defers the actual work
to an idle timer so rapid j/k navigation doesn't do redundant work."
  (when workbench--files-track-timer
    (cancel-timer workbench--files-track-timer))
  (let ((buf (current-buffer)))
    (setq workbench--files-track-timer
          (run-with-idle-timer 0.15 nil
                               (lambda ()
                                 (when (buffer-live-p buf)
                                   (with-current-buffer buf
                                     (workbench--files-track-point-now))))))))

(defun workbench--files-track-point-now ()
  "Record the files workspace's current directory and file at point."
  (setq workbench--files-track-timer nil)
  (when (and (fboundp '+workspace-current-name)
             (equal (+workspace-current-name) "files")
             (workbench--files-real-dired-p))
    (setq workbench--files-directory default-directory
          workbench--files-file (ignore-errors (dired-get-filename nil t)))))

(defun workbench--files-install-tracker ()
  "Install the files-workspace position tracker in this Dired buffer."
  (add-hook 'post-command-hook #'workbench--files-track-point nil t)
  (add-hook 'kill-buffer-hook #'workbench--files-cancel-tracker nil t))

(defun workbench--files-cancel-tracker ()
  "Cancel any pending files position tracking timer."
  (when workbench--files-track-timer
    (cancel-timer workbench--files-track-timer)
    (setq workbench--files-track-timer nil)))

(defun workbench--files-dirvish-layout-active-p ()
  "Return non-nil when the current buffer has an active Dirvish layout."
  (and (fboundp 'dirvish-curr)
       (fboundp 'dv-curr-layout)
       (when-let ((dirvish (dirvish-curr)))
         (dv-curr-layout dirvish))))

(defun workbench--files-workspace-full-frame (&rest _)
  "Show full-frame Dirvish when the files workspace becomes current.
Deferred with `run-at-time' so it runs after persp has finished restoring the
workspace's windows. Rebuilds at the directory and file last browsed."
  (when (and (fboundp '+workspace-current-name)
             (equal (+workspace-current-name) "files")
             (display-graphic-p))
    (run-at-time
     0 nil
     (lambda ()
       (when (and (equal (+workspace-current-name) "files")
                  (not (workbench--files-dirvish-layout-active-p)))
         (workbench/open-files-full-frame workbench--files-directory
                                          workbench--files-file))))))

(add-hook 'dired-mode-hook #'workbench--files-install-tracker)
(add-hook 'persp-activated-functions #'workbench--files-workspace-full-frame)
