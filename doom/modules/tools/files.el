;;; tools/files.el -*- lexical-binding: t; -*-

(defun workbench--project-root ()
  "Return the current project root, or `default-directory' when outside a project."
  (or (when-let ((project (project-current nil)))
        (project-root project))
      default-directory))

(defun workbench/open-files ()
  "Open the workbench file manager at the current project root."
  (interactive)
  (let ((directory (workbench--project-root)))
    (if (fboundp 'dirvish)
        (dirvish directory)
      (dired directory))))

(defun workbench--selected-path ()
  "Return the path at point in Dired or Dirvish."
  (or (dired-get-file-for-visit)
      (user-error "No file at point")))

(defun workbench--project-directory-for-path (path)
  "Return the project directory to open for PATH."
  (file-truename
   (if (file-directory-p path)
       path
     (file-name-directory path))))

(defun workbench/open-selected-path-as-project-workspace ()
  "Open the selected Dired or Dirvish path as a project workspace."
  (interactive)
  (workbench/open-project-workspace
   (workbench--project-directory-for-path (workbench--selected-path))))

(defun workbench--treemacs-display (directory)
  "Open Treemacs showing DIRECTORY as its only project, and focus it.
Roots at DIRECTORY even when it is not a VCS project (ADR 0043)."
  (require 'treemacs)
  (let ((path (treemacs--canonical-path (file-truename directory)))
        (name (workbench--directory-name directory)))
    (treemacs-select-window)
    (unless (treemacs-is-path path :in-workspace)
      (treemacs-do-add-project-to-workspace path name))
    (dolist (project (treemacs-workspace->projects (treemacs-current-workspace)))
      (unless (treemacs-is-path path :same-as (treemacs-project->path project))
        (treemacs-do-remove-project-from-workspace project)))
    (when-let ((window (workbench--treemacs-window)))
      (select-window window))))

(defun workbench/open-project-tree ()
  "Toggle the project tree, rooted at the current project directory.
Closes the tree if it is visible; otherwise opens it rooted at the
current project (or `default-directory') and focuses it."
  (interactive)
  (unless (fboundp 'treemacs-select-window)
    (user-error "Treemacs is not available"))
  (let ((window (and (fboundp 'treemacs-get-local-window)
                     (treemacs-get-local-window))))
    (if window
        (delete-window window)
      (workbench--treemacs-display (workbench--project-root)))))

(after! treemacs
  (setq treemacs-position 'left
        treemacs-width 25
        treemacs-show-hidden-files t)
  (treemacs-follow-mode +1)
  (treemacs-git-mode 'deferred))
