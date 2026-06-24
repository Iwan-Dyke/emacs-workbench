;;; workflows/coding.el -*- lexical-binding: t; -*-

(defun workbench--directory-name (directory)
  "Return a workspace-friendly name for DIRECTORY."
  (file-name-nondirectory (directory-file-name directory)))

(defun workbench/open-project-dashboard (directory)
  "Open the project dashboard for DIRECTORY."
  (let* ((project-directory (file-truename directory))
         (project-name (workbench--directory-name project-directory))
         (buffer (get-buffer-create (format "*workbench:%s*" project-name))))
    (switch-to-buffer buffer)
    (special-mode)
    (setq-local default-directory project-directory)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (insert project-name "\n")
      (insert (abbreviate-file-name project-directory) "\n"))))

(defun workbench/open-project-workspace (directory)
  "Open DIRECTORY as a workbench project workspace.
Creates the workspace and lands on the project placeholder. The tree
\(SPC e) and the project AI pane are summoned on demand (ADR 0044)."
  (interactive "DProject directory: ")
  (let* ((project-directory (file-truename directory))
         (workspace-name (workbench--directory-name project-directory)))
    (if (fboundp '+workspace-switch)
        (+workspace-switch workspace-name t)
      (user-error "Doom workspaces are not available"))
    (setq default-directory project-directory)
    (workbench/open-project-dashboard project-directory)))

(defun workbench/open-project-workspace-dwim ()
  "Open a project workspace from the selected path, or by prompting."
  (interactive)
  (if (derived-mode-p 'dired-mode)
      (workbench/open-selected-path-as-project-workspace)
    (call-interactively #'workbench/open-project-workspace)))

(defun workbench/open-startup-workspaces ()
  "Open the minimal startup workspaces."
  (interactive)
  (unless (and (fboundp '+workspace-switch)
               (fboundp '+workspace-current-name))
    (user-error "Doom workspaces are not available"))
  (let ((starting-workspace (+workspace-current-name)))
    (+workspace-switch "files" t)
    (workbench/open-files)
    (+workspace-switch starting-workspace t)))

(defvar workbench--startup-workspaces-opened nil
  "Whether startup workspaces have been opened for this Emacs process.")

(defun workbench--open-startup-workspaces-once (&rest _)
  "Open startup workspaces once after the first usable frame exists.
Guards on `display-graphic-p' so the daemon's frameless `emacs-startup-hook'
call is skipped and the setup runs from `server-after-make-frame-hook', once
a real frame exists and the current workspace is the dashboard."
  (when (and (not workbench--startup-workspaces-opened)
             (display-graphic-p))
    (setq workbench--startup-workspaces-opened t)
    (run-at-time 0.2 nil #'workbench/open-startup-workspaces)))

(add-hook 'emacs-startup-hook #'workbench--open-startup-workspaces-once)
(add-hook 'server-after-make-frame-hook #'workbench--open-startup-workspaces-once)
