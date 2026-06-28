;;; workflows/project-dashboard.el -*- lexical-binding: t; -*-

(declare-function workbench--directory-name "modules/tools/files")
(declare-function workbench--project-root "modules/tools/files")
(declare-function workbench/open-files "modules/tools/files")
(declare-function workbench/open-project-tree "modules/tools/files")
(declare-function workbench/toggle-project-ai "modules/workflows/ai")

;;; Data collection

(defun workbench--dashboard-shell (directory &rest args)
  "Run ARGS as a process in DIRECTORY, return trimmed stdout or nil on failure."
  (let ((default-directory directory))
    (with-temp-buffer
      (when (zerop (apply #'call-process (car args) nil t nil (cdr args)))
        (string-trim (buffer-string))))))

(defun workbench--dashboard-shell-lines (directory &rest args)
  "Run ARGS in DIRECTORY, return stdout as a list of non-empty lines."
  (when-let ((output (apply #'workbench--dashboard-shell directory args)))
    (and (not (string-empty-p output))
         (split-string output "\n" t))))

(defun workbench--dashboard-git-p (directory)
  "Return non-nil if DIRECTORY is inside a git repository."
  (workbench--dashboard-shell directory "git" "rev-parse" "--git-dir"))

(defun workbench--dashboard-overview (directory)
  "Collect project overview for DIRECTORY."
  (let ((type (cond
               ((file-exists-p (expand-file-name "justfile" directory)) "justfile")
               ((file-exists-p (expand-file-name "pyproject.toml" directory)) "python (pyproject)")
               ((file-exists-p (expand-file-name "go.mod" directory)) "go")
               ((file-exists-p (expand-file-name "Cargo.toml" directory)) "rust")
               ((file-exists-p (expand-file-name "package.json" directory)) "node")
               ((file-exists-p (expand-file-name "Makefile" directory)) "make")
               ((file-exists-p (expand-file-name "Terraform" directory)) "terraform")
               (t nil))))
    (list :name (workbench--directory-name directory)
          :path (abbreviate-file-name directory)
          :type type
          :has-readme (or (file-exists-p (expand-file-name "README.md" directory))
                         (file-exists-p (expand-file-name "README.org" directory))
                         (file-exists-p (expand-file-name "README" directory))))))

(defun workbench--dashboard-git (directory)
  "Collect git state for DIRECTORY. Returns plist or nil if not a git repo."
  (when (workbench--dashboard-git-p directory)
    (let ((branch (workbench--dashboard-shell directory "git" "branch" "--show-current"))
          (status-lines (workbench--dashboard-shell-lines directory "git" "status" "--porcelain"))
          (ahead-behind (workbench--dashboard-shell directory
                          "git" "rev-list" "--left-right" "--count" "HEAD...@{upstream}"))
          (last-commit (workbench--dashboard-shell directory
                         "git" "log" "-1" "--format=%h %s (%ar)")))
      (let ((modified 0) (untracked 0))
        (dolist (line (or status-lines '()))
          (if (string-prefix-p "?" line)
              (cl-incf untracked)
            (cl-incf modified)))
        (let (ahead behind)
          (when (and ahead-behind (string-match "\\([0-9]+\\)\t\\([0-9]+\\)" ahead-behind))
            (setq ahead (string-to-number (match-string 1 ahead-behind))
                  behind (string-to-number (match-string 2 ahead-behind))))
          (list :branch (or branch "(detached)")
                :modified modified
                :untracked untracked
                :ahead (or ahead 0)
                :behind (or behind 0)
                :last-commit last-commit))))))

(defun workbench--dashboard-languages (directory)
  "Collect language breakdown from git ls-files in DIRECTORY.
Returns alist of (language . count) sorted by count descending, top 5."
  (when-let ((files (workbench--dashboard-shell-lines directory "git" "ls-files")))
    (let ((counts (make-hash-table :test 'equal)))
      (dolist (file files)
        (when-let ((ext (file-name-extension file)))
          (puthash ext (1+ (gethash ext counts 0)) counts)))
      (let (pairs)
        (maphash (lambda (k v) (push (cons k v) pairs)) counts)
        (setq pairs (sort pairs (lambda (a b) (> (cdr a) (cdr b)))))
        (seq-take pairs 5)))))

(defun workbench--dashboard-commands (directory)
  "Collect available commands from DIRECTORY's task runner."
  (let ((justfile (expand-file-name "justfile" directory)))
    (if (file-exists-p justfile)
        (workbench--dashboard-shell-lines directory "just" "--list" "--unsorted")
      (let ((makefile (expand-file-name "Makefile" directory)))
        (when (file-exists-p makefile)
          (workbench--dashboard-shell-lines directory
            "make" "-qp" "--no-print-directory"))))))

(defun workbench--dashboard-commands-justfile (directory)
  "Parse justfile recipe names from DIRECTORY."
  (when (file-exists-p (expand-file-name "justfile" directory))
    (workbench--dashboard-shell-lines directory "just" "--summary")))

(defun workbench--dashboard-recent (directory)
  "Collect recent activity for DIRECTORY."
  (when (workbench--dashboard-git-p directory)
    (list :commits (workbench--dashboard-shell-lines directory
                     "git" "log" "--oneline" "-5")
          :changed (workbench--dashboard-shell-lines directory
                     "git" "diff" "--name-only" "HEAD"))))

;;; Rendering

(defun workbench--dashboard-render-heading (text)
  "Insert TEXT as a section heading."
  (insert (propertize text 'face 'bold) "\n"))

(defun workbench--dashboard-render-overview (data)
  "Render the overview section from DATA plist."
  (workbench--dashboard-render-heading "Overview")
  (insert "  " (plist-get data :name) "\n")
  (insert "  " (plist-get data :path) "\n")
  (when-let ((type (plist-get data :type)))
    (insert "  " type "\n"))
  (insert "\n"))

(defun workbench--dashboard-render-git (data)
  "Render the git section from DATA plist, or a not-a-repo message."
  (workbench--dashboard-render-heading "Git")
  (if (not data)
      (insert "  not a git repository\n\n")
    (insert "  " (plist-get data :branch))
    (let ((mod (plist-get data :modified))
          (unt (plist-get data :untracked)))
      (if (and (zerop mod) (zerop unt))
          (insert (propertize "  clean" 'face 'success))
        (insert "  "
                (propertize (format "%d modified" mod) 'face 'warning)
                (if (> unt 0) (format ", %d untracked" unt) ""))))
    (insert "\n")
    (let ((ahead (plist-get data :ahead))
          (behind (plist-get data :behind)))
      (when (or (> ahead 0) (> behind 0))
        (insert (format "  ↑%d ↓%d\n" ahead behind))))
    (when-let ((commit (plist-get data :last-commit)))
      (insert "  " commit "\n"))
    (insert "\n")))

(defun workbench--dashboard-render-languages (data)
  "Render language breakdown from DATA alist."
  (when data
    (workbench--dashboard-render-heading "Languages")
    (let ((total (apply #'+ (mapcar #'cdr data))))
      (dolist (pair data)
        (insert (format "  .%-12s %3d%%\n"
                        (car pair)
                        (round (* 100.0 (/ (float (cdr pair)) total)))))))
    (insert "\n")))

(defun workbench--dashboard-render-commands (directory)
  "Render available commands for DIRECTORY."
  (when-let ((recipes (workbench--dashboard-commands-justfile directory)))
    (workbench--dashboard-render-heading "Commands")
    (insert "  just " (string-join recipes "  ") "\n\n")))

(defun workbench--dashboard-render-recent (data)
  "Render recent activity from DATA plist."
  (when data
    (workbench--dashboard-render-heading "Recent")
    (when-let ((commits (plist-get data :commits)))
      (dolist (c commits)
        (insert "  " c "\n")))
    (when-let ((changed (plist-get data :changed)))
      (insert "  ---\n")
      (dolist (f (seq-take changed 10))
        (insert "  " f "\n")))
    (insert "\n")))

(defun workbench--dashboard-render-actions (directory overview)
  "Render the actions section with keybinding hints."
  (workbench--dashboard-render-heading "Actions")
  (insert "  [f]iles  [s]earch  [g]it  [t]erm  [a]i  [e]xplorer  [R]efresh")
  (when (plist-get overview :has-readme)
    (insert "  [r]eadme"))
  (insert "\n"))

;;; Keymap

(defvar workbench-project-dashboard-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "f" #'project-find-file)
    (define-key map "s" #'project-find-regexp)
    (define-key map "g" #'magit-status)
    (define-key map "t" #'workbench/toggle-popup-terminal)
    (define-key map "a" #'workbench/toggle-project-ai)
    (define-key map "e" #'workbench/open-project-tree)
    (define-key map "R" #'workbench/refresh-project-dashboard)
    (define-key map "r" #'workbench--dashboard-open-readme)
    map)
  "Keymap for the project dashboard buffer.")

;;; Entry points

(defun workbench--dashboard-open-readme ()
  "Open the project README."
  (interactive)
  (let ((dir (or (bound-and-true-p workbench--dashboard-directory) default-directory)))
    (cond
     ((file-exists-p (expand-file-name "README.md" dir))
      (find-file (expand-file-name "README.md" dir)))
     ((file-exists-p (expand-file-name "README.org" dir))
      (find-file (expand-file-name "README.org" dir)))
     (t (user-error "No README found")))))

(defun workbench/refresh-project-dashboard ()
  "Refresh the current project dashboard."
  (interactive)
  (when (bound-and-true-p workbench--dashboard-directory)
    (workbench/open-project-dashboard workbench--dashboard-directory)))

(defun workbench/open-project-dashboard (directory)
  "Open the project intelligence dashboard for DIRECTORY."
  (let* ((project-directory (file-truename directory))
         (project-identity (workbench--project-identity-name project-directory))
         (buffer (get-buffer-create (format "*workbench:%s*" project-identity)))
         (overview (workbench--dashboard-overview project-directory))
         (git (workbench--dashboard-git project-directory))
         (languages (workbench--dashboard-languages project-directory))
         (recent (workbench--dashboard-recent project-directory)))
    (switch-to-buffer buffer)
    (let ((inhibit-read-only t))
      (erase-buffer)
      (workbench--dashboard-render-overview overview)
      (workbench--dashboard-render-git git)
      (workbench--dashboard-render-languages languages)
      (workbench--dashboard-render-commands project-directory)
      (workbench--dashboard-render-recent recent)
      (workbench--dashboard-render-actions project-directory overview))
    (goto-char (point-min))
    (special-mode)
    (use-local-map (make-composed-keymap workbench-project-dashboard-mode-map
                                         special-mode-map))
    (setq-local default-directory project-directory)
    (setq-local workbench--dashboard-directory project-directory)))

(provide 'workbench-project-dashboard)
