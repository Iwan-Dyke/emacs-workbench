;;; workflows/coding.el -*- lexical-binding: t; -*-

(declare-function workbench--directory-name "modules/tools/files")
(declare-function workbench/open-selected-path-as-project-workspace "modules/tools/files")

(defun workbench--project-identity-name (directory)
  "Return a workspace name for DIRECTORY: the bare directory name.
If a workspace with that name already exists for a different directory,
appends a numeric suffix (e.g. utils<2>)."
  (let ((base (file-name-nondirectory (directory-file-name (file-truename directory)))))
    (if (or (not (fboundp '+workspace-exists-p))
            (not (+workspace-exists-p base)))
        base
      (let ((n 2) candidate)
        (while (progn
                 (setq candidate (format "%s<%d>" base n))
                 (+workspace-exists-p candidate))
          (setq n (1+ n)))
        candidate))))

(defun workbench/open-project-workspace (directory)
  "Open DIRECTORY as a workbench project workspace.
If a workspace with the directory's name already exists, switches to it.
Otherwise creates the workspace and lands on the project placeholder."
  (interactive "DProject directory: ")
  (let* ((project-directory (file-truename directory))
         (base (file-name-nondirectory (directory-file-name project-directory))))
    (unless (fboundp '+workspace-switch)
      (user-error "Doom workspaces are not available"))
    (if (+workspace-exists-p base)
        (+workspace-switch base)
      (let ((workspace-name (workbench--project-identity-name project-directory)))
        (+workspace-switch workspace-name t)
        (setq default-directory project-directory)
        (workbench/open-project-dashboard project-directory)))))

(defun workbench/open-project-workspace-dwim ()
  "Open a project workspace from the selected path, or by prompting."
  (interactive)
  (if (derived-mode-p 'dired-mode)
      (workbench/open-selected-path-as-project-workspace)
    (call-interactively #'workbench/open-project-workspace)))
