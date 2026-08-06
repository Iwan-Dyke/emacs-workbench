;;; tools/files.el -*- lexical-binding: t; -*-

(require 'cl-lib)
(declare-function workbench--treemacs-window "modules/system/interface")

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
  (when (and (fboundp 'dirvish-layout-toggle)
             (fboundp 'dirvish-curr)
             (dirvish-curr)
             ;; Only toggle layout ON — skip if already active.
             (not (and (fboundp 'dv-curr-layout)
                       (dv-curr-layout (dirvish-curr)))))
    (dirvish-layout-toggle))
  (when (and file (file-exists-p file))
    (dired-goto-file file)))

(defun workbench--selected-path ()
  "Return the path at point in Dired or Dirvish.
Signals `user-error' if point is not on a file entry (e.g. header or blank line)."
  (condition-case nil
      (dired-get-file-for-visit)
    (error (user-error "No file at point — move to a file entry first"))))

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

(defun workbench--treemacs-strip-extra-projects (keep-path)
  "Remove all projects from the current treemacs workspace except KEEP-PATH.
Defensive cleanup for when treemacs-persp or treemacs-projectile inject
extra projects during init or workspace switch."
  (let* ((ws (treemacs-current-workspace))
         (projects (treemacs-workspace->projects ws))
         (dominated (seq-filter
                     (lambda (p)
                       (not (treemacs-is-path keep-path :same-as (treemacs-project->path p))))
                     projects)))
    (dolist (p dominated)
      (treemacs-do-remove-project-from-workspace p))))

(defun workbench--treemacs-display (directory)
  "Open Treemacs showing DIRECTORY as its only project, and focus it.
Roots at DIRECTORY even when it is not a VCS project (ADR 0043).
Uses `treemacs--init' to create the treemacs buffer non-interactively,
avoiding `treemacs-select-window' and `treemacs' which prompt for a project.

When an existing Treemacs buffer shows a different project, kills it and
reinitialises from scratch. Reusing a stale buffer via project add/remove
leaves Treemacs in an inconsistent state when switching between project
workspaces."
  (require 'treemacs)
  (let ((path (treemacs--canonical-path (file-truename directory)))
        (name (workbench--directory-name directory)))
    (if (workbench--treemacs-window)
        ;; Already visible — check if it shows the right project
        (let ((current-projects (treemacs-workspace->projects (treemacs-current-workspace))))
          (if (and (= 1 (length current-projects))
                   (treemacs-is-path path :same-as (treemacs-project->path (car current-projects))))
              ;; Correct project already showing — just select it
              (select-window (workbench--treemacs-window))
            ;; Wrong project — kill and reinitialise
            (delete-window (workbench--treemacs-window))
            (when-let ((buf (treemacs-get-local-buffer)))
              (kill-buffer buf))
            (treemacs--init path name)))
      ;; Not visible
      (let ((buf (treemacs-get-local-buffer)))
        (if buf
            ;; Buffer exists but hidden — check if it's for the right project
            (let ((current-projects (when (buffer-live-p buf)
                                      (treemacs-workspace->projects (treemacs-current-workspace)))))
              (if (and current-projects
                       (= 1 (length current-projects))
                       (treemacs-is-path path :same-as (treemacs-project->path (car current-projects))))
                  ;; Same project — just re-show it
                  (treemacs-select-window)
                ;; Different project — kill stale buffer and start fresh
                (kill-buffer buf)
                (treemacs--init path name)))
          ;; No buffer — create from scratch
          (treemacs--init path name))))
    ;; Defensive: strip any extra projects that treemacs-persp or
    ;; treemacs-projectile may have injected during init.
    (let ((current-projects (treemacs-workspace->projects (treemacs-current-workspace))))
      (when (> (length current-projects) 1)
        (workbench--treemacs-strip-extra-projects path)))
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

(after! (dired evil)
  (evil-define-key 'normal dired-mode-map
    "r" #'revert-buffer))

;; Set before treemacs loads — the persist file is read at load time and will
;; prompt about missing projects unless this is already set.
(setq treemacs-missing-project-action 'remove)

;; Truncate the persist file BEFORE treemacs loads so it starts with a clean
;; slate. The workbench manages roots explicitly via `workbench--treemacs-display'
;; so persisted state is never useful. treemacs-persp still needs the file to
;; exist for workspace scoping, but it should be empty on startup.
(let ((persist-file (expand-file-name "cache/treemacs-persist"
                      (expand-file-name ".local/" user-emacs-directory))))
  (when (file-exists-p persist-file)
    (with-temp-file persist-file
      (insert ""))))

(after! treemacs
  ;; Silently remove projects whose paths no longer exist instead of prompting.
  ;; Stale paths accumulate when repos are deleted or moved, and the prompt
  ;; blocks non-interactive treemacs init (e.g. SPC p o full layout).
  (setq treemacs-missing-project-action 'remove)

  ;; Prevent treemacs from persisting workspace state on exit or workspace
  ;; operations. The workbench sets roots explicitly on every SPC p o — any
  ;; persisted state just causes stale multi-project accumulation.
  (remove-hook 'kill-emacs-hook #'treemacs--persist)
  (advice-add #'treemacs--persist :override #'ignore)

  ;; Prevent treemacs-persp from copying fallback workspace projects into new
  ;; perspectives. When treemacs-persp can't find a user project for a new
  ;; perspective, it copies ALL projects from the first workspace — polluting
  ;; every new workspace with stale roots. Override to create empty workspaces
  ;; instead; `workbench--treemacs-display' will set the correct root.
  (with-eval-after-load 'treemacs-persp
    (defun treemacs-persp--create-workspace (name)
      "Create a new empty workspace for the given persp NAME.
Workbench override: never copies fallback projects."
      (let* ((ws-result (treemacs-do-create-workspace name))
             (ws-status (car ws-result))
             (ws (cadr ws-result)))
        (unless (eq ws-status 'success)
          (treemacs-log "Failed to create workspace for perspective: %s" ws)
          (setq ws (car treemacs--workspaces)))
        ;; Only set a project if treemacs can detect one from projectile/project.el
        (let ((root-path (treemacs--find-current-user-project)))
          (when root-path
            (setf (treemacs-workspace->projects ws)
                  (list (treemacs-project->create!
                         :name (treemacs--filename root-path)
                         :path root-path
                         :path-status (treemacs--get-path-status root-path))))))
        ws)))

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
  ;; Enable evil-compatible keybindings for file operations (cf, cd, d, R, etc.)
  ;; treemacs-evil lives in treemacs/src/extra/ which straight doesn't auto-add
  ;; to load-path, so ensure it's reachable.
  (let ((extra-dir (expand-file-name
                    "straight/repos/treemacs/src/extra/"
                    (or (bound-and-true-p straight-base-dir)
                        (expand-file-name ".local/" user-emacs-directory)))))
    (when (file-directory-p extra-dir)
      (add-to-list 'load-path extra-dir)))
  (require 'treemacs-evil)
  (treemacs-follow-mode +1)
  (treemacs-git-mode 'deferred))
