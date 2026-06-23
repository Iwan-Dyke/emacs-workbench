;;; workflows/coding.el -*- lexical-binding: t; -*-

(defun workbench--directory-name (directory)
  "Return a workspace-friendly name for DIRECTORY."
  (file-name-nondirectory (directory-file-name directory)))

(defun workbench/open-project-workspace (directory)
  "Open DIRECTORY as a workbench project workspace."
  (interactive "DProject directory: ")
  (let* ((project-directory (file-truename directory))
         (workspace-name (workbench--directory-name project-directory)))
    (if (fboundp '+workspace-switch)
        (+workspace-switch workspace-name t)
      (user-error "Doom workspaces are not available"))
    (setq default-directory project-directory)
    (workbench/open-files)))
