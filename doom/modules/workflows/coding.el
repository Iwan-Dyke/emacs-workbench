;;; workflows/coding.el -*- lexical-binding: t; -*-

(declare-function workbench--directory-name "modules/tools/files")
(declare-function workbench--selected-path "modules/tools/files")
(declare-function workbench--project-directory-for-path "modules/tools/files")
(declare-function workbench/open-selected-path-as-project-workspace "modules/tools/files")
(declare-function workbench--treemacs-display "modules/tools/files")
(declare-function workbench/open-project-dashboard "modules/workflows/project-dashboard")
(declare-function workbench--show-project-ai "modules/workflows/ai")

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

(defvar workbench--workspace-directories (make-hash-table :test 'equal)
  "Hash table mapping workspace name → project directory (truename).
Used as a fallback when the dashboard buffer has been killed.")

(defun workbench/open-project-workspace (directory)
  "Open DIRECTORY as a workbench project workspace.
If a workspace with the directory's name already exists AND belongs to the
same directory, switches to it (checking base name and all suffixed variants).
Otherwise creates a new workspace (with a numeric suffix if the base name
collides)."
  (interactive "DProject directory: ")
  (let* ((project-directory (file-truename directory))
         (base (file-name-nondirectory (directory-file-name project-directory))))
    (unless (fboundp '+workspace-switch)
      (user-error "Doom workspaces are not available"))
    ;; Check base name and all suffixed variants for a match
    (let ((match (workbench--find-workspace-for-directory base project-directory)))
      (if match
          (progn
            (+workspace-switch match)
            ;; Ensure registry is populated (C8 fix)
            (puthash match (file-name-as-directory project-directory)
                     workbench--workspace-directories))
        (let ((workspace-name (workbench--project-identity-name project-directory)))
          (+workspace-switch workspace-name t)
          (setq default-directory project-directory)
          (puthash workspace-name (file-name-as-directory project-directory)
                   workbench--workspace-directories)
          (workbench/open-project-dashboard project-directory))))))

(defun workbench--find-workspace-for-directory (base directory)
  "Find an existing workspace for DIRECTORY, checking BASE and BASE<N> variants.
Returns the workspace name if found, nil otherwise."
  (let ((target (file-name-as-directory (file-truename directory))))
    (cond
     ;; Check base name
     ((and (+workspace-exists-p base)
           (workbench--workspace-matches-directory-p base directory))
      base)
     ;; Check suffixed names (iterate up to 10 regardless of gaps)
     (t
      (let ((n 2) candidate found)
        (while (and (not found) (<= n 10))
          (setq candidate (format "%s<%d>" base n))
          (when (and (+workspace-exists-p candidate)
                     (workbench--workspace-matches-directory-p candidate directory))
            (setq found candidate))
          (setq n (1+ n)))
        found)))))

(defun workbench--workspace-matches-directory-p (workspace-name directory)
  "Return non-nil if WORKSPACE-NAME belongs to DIRECTORY.
Checks the dashboard buffer first, then falls back to the workspace
directory registry (for when the buffer has been killed)."
  (let ((target (file-name-as-directory (file-truename directory))))
    (or
     ;; Primary: check dashboard buffer's default-directory
     (let ((buf (get-buffer (format "*workbench:%s*" workspace-name))))
       (and buf (buffer-live-p buf)
            (equal (file-name-as-directory
                    (file-truename (buffer-local-value 'default-directory buf)))
                   target)))
     ;; Fallback: check the directory registry
     (equal (gethash workspace-name workbench--workspace-directories) target))))

(defun workbench--workspace-directory-cleanup (&rest _)
  "Remove entries from `workbench--workspace-directories' for dead workspaces.
Only runs when the hash table exceeds 20 entries to avoid overhead on every
workspace switch."
  (when (> (hash-table-count workbench--workspace-directories) 20)
    (let ((stale-keys nil))
      (maphash (lambda (ws _dir)
                 (unless (+workspace-exists-p ws)
                   (push ws stale-keys)))
               workbench--workspace-directories)
      (dolist (ws stale-keys)
        (remhash ws workbench--workspace-directories)))))

(add-hook 'persp-activated-functions #'workbench--workspace-directory-cleanup)

(defun workbench/open-project-workspace-dwim ()
  "Open a project workspace from the selected path, or by prompting."
  (interactive)
  (if (derived-mode-p 'dired-mode)
      (workbench/open-selected-path-as-project-workspace)
    (call-interactively #'workbench/open-project-workspace)))

(defun workbench/open-project-workspace-full-layout ()
  "Open a project workspace with the full coding layout: Treemacs | Code | AI.
From Dired/Dirvish, uses the selected path. Otherwise prompts.
Creates or switches to the workspace, then builds the three-pane layout:
  - Treemacs tree on the left (project root)
  - Project dashboard in the centre
  - Profile default AI pane on the right

This is the one-shot equivalent of: SPC p o → SPC e → SPC t c/k."
  (interactive)
  ;; Step 1: open or switch to the workspace (reuses existing logic)
  (let ((directory (if (derived-mode-p 'dired-mode)
                       (workbench--project-directory-for-path
                        (workbench--selected-path))
                     (read-directory-name "Project directory: "))))
    (workbench/open-project-workspace directory)
    ;; Step 2: clear any existing layout and build fresh
    (delete-other-windows)
    ;; Step 3: open Treemacs on the left
    (workbench--treemacs-display directory)
    ;; Step 4: select the main editing window (right of Treemacs)
    (other-window 1)
    ;; Step 5: show the project dashboard in the centre
    (workbench/open-project-dashboard directory)
    ;; Step 6: open the AI pane on the right
    (workbench--show-project-ai workbench/default-ai-tool)))
