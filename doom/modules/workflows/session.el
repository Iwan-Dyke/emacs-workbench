;;; workflows/session.el -*- lexical-binding: t; -*-

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
  "Open the startup workspaces: a files browser and the default AI agent.
Leaves the original (dashboard) workspace selected."
  (interactive)
  (unless (and (fboundp '+workspace-switch)
               (fboundp '+workspace-current-name))
    (user-error "Doom workspaces are not available"))
  (let ((starting-workspace (+workspace-current-name)))
    (+workspace-switch "files" t)
    (workbench/open-files)
    (workbench/open-default-ai-workspace)
    (+workspace-switch starting-workspace t)
    ;; Nothing displays the workspace list on its own after we build it in the
    ;; background, so the new workspaces stay invisible until you switch into
    ;; one. Show the workspace tabline now so they are visible immediately.
    (+workspace/display)))

(defvar workbench--startup-workspaces-opened nil
  "Whether startup workspaces have been opened for this Emacs process.")

(defun workbench--open-startup-workspaces-once (&rest _)
  "Open startup workspaces once after the first usable graphic frame exists.
Guards on `display-graphic-p' so the daemon's frameless `emacs-startup-hook'
call is skipped and the setup runs from `server-after-make-frame-hook', once a
real frame exists and is large enough to hold the workspace layouts."
  (when (and (not workbench--startup-workspaces-opened)
             (display-graphic-p))
    (setq workbench--startup-workspaces-opened t)
    (run-at-time 0.2 nil #'workbench/open-startup-workspaces)))

(add-hook 'emacs-startup-hook #'workbench--open-startup-workspaces-once)
(add-hook 'server-after-make-frame-hook #'workbench--open-startup-workspaces-once)

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

(defun workbench--files-track-point ()
  "Record the files workspace's current directory and file at point.
Runs from a buffer-local `post-command-hook' in Dired buffers, so the position
is captured as you browse and survives Dirvish collapsing its layout later."
  (when (and (fboundp '+workspace-current-name)
             (equal (+workspace-current-name) "files")
             (workbench--files-real-dired-p))
    (setq workbench--files-directory default-directory
          workbench--files-file (ignore-errors (dired-get-filename nil t)))))

(defun workbench--files-install-tracker ()
  "Install the files-workspace position tracker in this Dired buffer."
  (add-hook 'post-command-hook #'workbench--files-track-point nil t))

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
                  (not (and (fboundp 'dirvish-curr)
                            (dirvish-curr)
                            (dv-curr-layout (dirvish-curr)))))
         (workbench/open-files-full-frame workbench--files-directory
                                          workbench--files-file))))))

(add-hook 'dired-mode-hook #'workbench--files-install-tracker)
(add-hook 'persp-activated-functions #'workbench--files-workspace-full-frame)
