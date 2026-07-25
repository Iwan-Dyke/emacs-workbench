;;; test/test-helper.el --- Doom stubs and test infrastructure -*- lexical-binding: t; -*-

;; Provides minimal Doom Emacs stubs so workbench modules can be loaded in
;; batch Emacs without the full Doom framework. Tests run against real source
;; rather than copying functions.

(require 'ert)
(require 'cl-lib)
(require 'seq)
(require 'dired)

;;; ── Paths ──────────────────────────────────────────────────────────────────

(defvar workbench-test-root
  (file-name-directory (directory-file-name (file-name-directory load-file-name)))
  "Root directory of the emacs-workbench project.")

(defvar doom-user-dir
  (expand-file-name "doom/" workbench-test-root)
  "Points to the repo's doom/ directory (stub for Doom's variable).")

;;; ── Doom Macros (stubs) ────────────────────────────────────────────────────

(defmacro load! (file &optional dir _noerror)
  "Load FILE relative to DIR or `doom-user-dir'.
In tests, this loads the real source file so tests run against actual code."
  (let ((base (or dir 'doom-user-dir)))
    `(load (expand-file-name ,file ,base) nil t)))

(defmacro after! (_feature &rest body)
  "Execute BODY immediately. In real Doom this defers until FEATURE loads."
  (declare (indent 1))
  `(progn ,@body))

(defmacro add-hook! (hook &rest body)
  "Stub — defines any embedded functions but does not add hooks."
  (declare (indent 1))
  (let ((forms (if (and (consp (car body))
                        (memq (caar body) '(defun defun*)))
                   body
                 ;; Single lambda or function reference — just expand the body
                 body)))
    `(progn ,@forms)))

(defmacro map! (&rest _args)
  "Stub — keybinding macro. No-op in tests."
  nil)

(defmacro set-formatter! (&rest _args)
  "Stub — formatter registration. No-op in tests."
  nil)

(defmacro doom! (&rest _args)
  "Stub — module declaration. No-op in tests."
  nil)

;;; ── Doom Workspace Stubs ───────────────────────────────────────────────────

(defvar workbench-test--workspaces '()
  "List of workspace names that exist in the test environment.
Override in individual tests to simulate workspace state.")

(defvar workbench-test--current-workspace "main"
  "Current workspace name for the test environment.")

(defun +workspace-exists-p (name)
  "Return non-nil if NAME is in `workbench-test--workspaces'."
  (member name workbench-test--workspaces))

(defun +workspace-current-name ()
  "Return the test environment's current workspace name."
  workbench-test--current-workspace)

(defun +workspace-switch (_name &optional _create)
  "Stub — no-op in tests."
  nil)

(defun +workspace/new ()
  "Stub — no-op in tests."
  nil)

(defun +workspace/display ()
  "Stub — no-op in tests."
  nil)

(defun +workspaces-delete-associated-workspace-h (&rest _)
  "Stub — hook function that Doom defines."
  nil)

;;; ── Doom Variables ─────────────────────────────────────────────────────────

(defvar doom-modules '()
  "Stub — empty module list.")

(defvar doom-disabled-packages '()
  "Stub — no disabled packages.")

(defvar doom-init-ui-hook nil
  "Stub — UI init hook (not run in tests).")

(defvar persp-mode nil
  "Stub — persp-mode not active in tests.")

(defvar persp-auto-save-opt 1
  "Stub — persp auto-save option.")

(defvar persp-activated-functions nil
  "Stub — persp activation hook.")

;;; ── Feature Stubs ──────────────────────────────────────────────────────────

;; Prevent `require' calls from failing for packages not installed in batch.
;; Modules use (require 'foo nil t) which is safe, but some use bare require.

(defvar workbench-test--blocked-features
  '(treemacs-evil treemacs nerd-icons org-roam vterm)
  "Features that should not actually load in batch tests.")

(defun workbench-test--safe-require (orig feature &optional filename noerror)
  "Advice around `require' — block test-irrelevant packages from loading."
  (if (memq feature workbench-test--blocked-features)
      nil
    (condition-case nil
        (funcall orig feature filename noerror)
      (file-missing nil)
      (file-error nil)
      (void-function nil)
      (error nil))))

(advice-add 'require :around #'workbench-test--safe-require)

;; Provide features that modules check for
(provide 'nerd-icons)
(unless (fboundp 'nerd-icons-mdicon)
  (defun nerd-icons-mdicon (name &rest _) name))
(unless (fboundp 'nerd-icons-octicon)
  (defun nerd-icons-octicon (name &rest _) name))
(unless (fboundp 'nerd-icons-faicon)
  (defun nerd-icons-faicon (name &rest _) name))
(unless (fboundp 'nerd-icons-devicon)
  (defun nerd-icons-devicon (name &rest _) name))
(unless (fboundp 'nerd-icons-codicon)
  (defun nerd-icons-codicon (name &rest _) name))

;; Treemacs stubs
(unless (fboundp 'treemacs-get-local-window)
  (defun treemacs-get-local-window () nil))
(unless (fboundp 'treemacs-select-window)
  (defun treemacs-select-window () nil))
(unless (fboundp 'treemacs--canonical-path)
  (defun treemacs--canonical-path (p) p))
(unless (fboundp 'treemacs-is-path)
  (defun treemacs-is-path (_p &rest _) nil))
(unless (fboundp 'treemacs-do-add-project-to-workspace)
  (defun treemacs-do-add-project-to-workspace (&rest _) nil))
(unless (fboundp 'treemacs-do-remove-project-from-workspace)
  (defun treemacs-do-remove-project-from-workspace (&rest _) nil))
(unless (fboundp 'treemacs-current-workspace)
  (defun treemacs-current-workspace () nil))
(unless (fboundp 'treemacs-workspace->projects)
  (defun treemacs-workspace->projects (_ws) nil))
(unless (fboundp 'treemacs-project->path)
  (defun treemacs-project->path (_p) nil))
(unless (fboundp 'treemacs-follow-mode)
  (defun treemacs-follow-mode (&rest _) nil))
(unless (fboundp 'treemacs-git-mode)
  (defun treemacs-git-mode (&rest _) nil))

;; Vterm stubs
(unless (fboundp 'vterm-mode)
  (defun vterm-mode () nil))
(unless (fboundp 'vterm)
  (defun vterm (&optional _name) (get-buffer-create "*vterm*")))
(unless (fboundp 'vterm-send-string)
  (defun vterm-send-string (&rest _) nil))
(unless (fboundp 'vterm-send-return)
  (defun vterm-send-return () nil))

;; Evil stubs
(unless (fboundp 'evil-define-key)
  (defun evil-define-key (&rest _) nil))
(unless (fboundp 'evil-set-initial-state)
  (defun evil-set-initial-state (&rest _) nil))

;;; ── Module Loading Helpers ─────────────────────────────────────────────────

(defun workbench-test-load-module (path)
  "Load a module from PATH relative to doom-user-dir."
  (load (expand-file-name path doom-user-dir) nil t))

;;; ── Test Utilities ─────────────────────────────────────────────────────────

(defmacro workbench-test-with-temp-file (var content &rest body)
  "Create a temp file with CONTENT, bind path to VAR, execute BODY, clean up."
  (declare (indent 2))
  `(let ((,var (make-temp-file "wb-test-")))
     (unwind-protect
         (progn
           (with-temp-file ,var
             (insert ,content))
           ,@body)
       (delete-file ,var))))

(defmacro workbench-test-with-temp-dir (var &rest body)
  "Create a temp directory, bind path to VAR, execute BODY, clean up."
  (declare (indent 1))
  `(let ((,var (make-temp-file "wb-test-" t)))
     (unwind-protect
         (progn ,@body)
       (delete-directory ,var t))))

(provide 'test-helper)
;;; test-helper.el ends here
