;;; tools/files.el -*- lexical-binding: t; -*-

(require 'cl-lib)

(defun workbench--directory-name (directory)
  "Return a workspace-friendly name for DIRECTORY."
  (file-name-nondirectory (directory-file-name directory)))

(defun workbench--project-root ()
  "Return the current project root, or `default-directory' when outside a project."
  (or (when-let ((project (project-current nil)))
        (project-root project))
      default-directory))

(defun workbench/open-files ()
  "Open the workbench file manager at the current project root.
Uses Dired (Dirvish-enhanced via `dirvish-override-dired-mode') as a single
stable window rather than full-frame Dirvish. Full-frame Dirvish runs
`delete-other-windows' and restores its saved window configuration when focus
leaves the session, so it collapses (\"closes\") as soon as you move to another
window and cannot coexist with a layout. A plain Dired window survives window
navigation and sits beside other panes. Toggle the full-frame preview with `F'."
  (interactive)
  (dired (workbench--project-root)))

(defun workbench/open-files-full-frame (&optional directory file)
  "Open the file manager as full-frame Dirvish: listing plus preview pane.
Opens at DIRECTORY when given, else the current project root, and moves point
to FILE when it still exists. Built from a fresh single Dired window, because
full-frame Dirvish cannot survive being saved and restored across a workspace
switch (it returns as a blank buffer). The files workspace rebuilds it on
entry, passing back the directory and file it remembered; see
`workbench--files-workspace-full-frame'."
  (interactive)
  (delete-other-windows)
  (dired (or directory (workbench--project-root)))
  (when (fboundp 'dirvish-layout-toggle)
    (dirvish-layout-toggle))
  (when (and file (file-exists-p file))
    (dired-goto-file file)))

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
    (dolist (project (cl-remove-if
                      (lambda (p) (treemacs-is-path path :same-as (treemacs-project->path p)))
                      (treemacs-workspace->projects (treemacs-current-workspace))))
      (treemacs-do-remove-project-from-workspace project))
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
  ;; Unlock the tree's width so it can be resized like any other window
  ;; (SPC w r). Treemacs has three lock mechanisms:
  ;;   - `treemacs-width-is-initially-locked': locks on buffer creation
  ;;   - `treemacs--width-is-locked': internal, re-locks after resize ops
  ;;   - `treemacs-width-is-locked': public toggle (less reliable)
  ;; Disable all three; `treemacs-width' still sets the initial size.
  (setq treemacs-position 'left
        treemacs-width 25
        treemacs-width-is-initially-locked nil
        treemacs-width-is-locked nil
        treemacs-show-hidden-files t)
  ;; Internal var; may disappear in future treemacs versions.
  (when (boundp 'treemacs--width-is-locked)
    (setq treemacs--width-is-locked nil))
  (treemacs-follow-mode +1)
  (treemacs-git-mode 'deferred))
