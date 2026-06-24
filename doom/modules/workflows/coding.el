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
