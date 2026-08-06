;;; workflows/project-dashboard.el -*- lexical-binding: t; -*-

;; Project intelligence dashboard: overview, git, languages, deps, CI/CD.
;; Split into data collection and rendering sub-modules.

(declare-function workbench--directory-name "modules/tools/files")
(declare-function workbench--project-root "modules/tools/files")
(declare-function workbench/open-files "modules/tools/files")
(declare-function workbench/open-project-tree "modules/tools/files")
(declare-function workbench/toggle-project-ai "modules/workflows/ai")


(load! "project-dashboard-data")
(load! "project-dashboard-render")

;;; ── Cache ──────────────────────────────────────────────────────────────────

(defvar workbench--dashboard-cache (make-hash-table :test 'equal)
  "Cache of collected dashboard data, keyed by truename directory.")

(defun workbench--dashboard-cache-invalidate (directory)
  "Remove cached data for DIRECTORY."
  (remhash (file-truename directory) workbench--dashboard-cache))

(defun workbench--dashboard-collect (directory)
  "Collect all dashboard data for DIRECTORY. Returns plist.
Uses cache if available; call `workbench--dashboard-cache-invalidate' to force
re-collection."
  (let ((key (file-truename directory)))
    (or (gethash key workbench--dashboard-cache)
        (let ((data (list :overview (workbench--dashboard-overview directory)
                          :git (workbench--dashboard-git directory)
                          :languages (workbench--dashboard-languages directory)
                          :deps (workbench--dashboard-dependencies directory)
                          :cicd (workbench--dashboard-cicd directory)
                          :recent (workbench--dashboard-recent directory))))
          (puthash key data workbench--dashboard-cache)
          data))))

;;; ── Keymap ─────────────────────────────────────────────────────────────────

(defvar workbench-project-dashboard-mode-map
  (make-sparse-keymap)
  "Keymap for the project dashboard buffer.")

(after! evil
  (evil-define-key 'normal workbench-project-dashboard-mode-map
    "f" #'project-find-file
    "s" #'project-find-regexp
    "g" #'magit-status
    "t" #'workbench/toggle-popup-terminal
    "a" #'workbench/toggle-project-ai
    "e" #'workbench/open-project-tree
    "R" #'workbench/refresh-project-dashboard
    "r" #'workbench--dashboard-open-readme))

;;; ── Entry Points ───────────────────────────────────────────────────────────

(defun workbench--dashboard-open-readme ()
  "Open the project README in a separate buffer."
  (interactive)
  (let ((dir (or (bound-and-true-p workbench--dashboard-directory) default-directory)))
    (cond
     ((file-exists-p (expand-file-name "README.md" dir))
      (find-file (expand-file-name "README.md" dir)))
     ((file-exists-p (expand-file-name "README.org" dir))
      (find-file (expand-file-name "README.org" dir)))
     (t (user-error "No README found")))))

(defun workbench/refresh-project-dashboard ()
  "Refresh the current project dashboard (re-collects all data)."
  (interactive)
  (when (bound-and-true-p workbench--dashboard-directory)
    (workbench--dashboard-cache-invalidate workbench--dashboard-directory)
    (workbench/open-project-dashboard workbench--dashboard-directory)))

(defun workbench--dashboard-render-section (fn &rest args)
  "Call FN with ARGS, catching and reporting errors inline."
  (condition-case err
      (apply fn args)
    (error
     (insert (propertize (format "  [error: %s]\n" (error-message-string err))
                         'face 'error)))))

(defun workbench/open-project-dashboard (directory)
  "Open the project intelligence dashboard for DIRECTORY."
  (let* ((project-directory (file-truename directory))
         (workspace-name (+workspace-current-name))
         (buffer (get-buffer-create (format "*workbench:%s*" workspace-name)))
         (data (workbench--dashboard-collect project-directory))
         (overview (plist-get data :overview))
         (git (plist-get data :git))
         (languages (plist-get data :languages))
         (deps (plist-get data :deps))
         (cicd (plist-get data :cicd))
         (recent (plist-get data :recent)))
    (switch-to-buffer buffer)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (workbench--dashboard-render-section #'workbench--dashboard-render-overview overview)
      (workbench--dashboard-render-section #'workbench--dashboard-render-git git)
      (workbench--dashboard-render-section #'workbench--dashboard-render-languages languages)
      (workbench--dashboard-render-section #'workbench--dashboard-render-commands project-directory)
      (workbench--dashboard-render-section #'workbench--dashboard-render-dependencies deps)
      (workbench--dashboard-render-section #'workbench--dashboard-render-cicd cicd)
      (workbench--dashboard-render-section #'workbench--dashboard-render-recent recent)
      (workbench--dashboard-render-section #'workbench--dashboard-render-actions project-directory overview)
      (workbench--dashboard-render-section #'workbench--dashboard-render-readme project-directory))
    (goto-char (point-min))
    (special-mode)
    (use-local-map (make-composed-keymap workbench-project-dashboard-mode-map
                                         special-mode-map))
    (setq-local default-directory project-directory)
    (setq-local workbench--dashboard-directory project-directory)
    (when (fboundp 'evil-normal-state)
      (evil-normal-state))))

(provide 'workbench-project-dashboard)
