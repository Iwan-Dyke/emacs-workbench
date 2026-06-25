;;; workflows/coding.el -*- lexical-binding: t; -*-

(defun workbench--directory-name (directory)
  "Return a workspace-friendly name for DIRECTORY."
  (file-name-nondirectory (directory-file-name directory)))

(defun workbench--project-identity-name (directory)
  "Return a stable workspace-friendly identity name for DIRECTORY."
  (let* ((path (directory-file-name (file-truename directory)))
         (name (file-name-nondirectory path))
         (parent (file-name-nondirectory
                  (directory-file-name (file-name-directory path)))))
    (if (string-empty-p parent)
        name
      (format "%s-%s" parent name))))

(defun workbench/open-project-dashboard (directory)
  "Open the project dashboard for DIRECTORY."
  (let* ((project-directory (file-truename directory))
         (project-name (workbench--directory-name project-directory))
         (project-identity (workbench--project-identity-name project-directory))
         (buffer (get-buffer-create (format "*workbench:%s*" project-identity))))
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
         (workspace-name (workbench--project-identity-name project-directory)))
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
