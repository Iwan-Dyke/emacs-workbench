;;; workflows/project-dashboard-render.el -*- lexical-binding: t; -*-

;; Rendering for the project dashboard: faces, icons, section renderers.

(require 'nerd-icons nil t)
(require 'cl-lib)

(declare-function workbench--dashboard-detect-task-runner "project-dashboard-data")

;;; ── Icons ──────────────────────────────────────────────────────────────────

(defun workbench--dashboard-icon (fn name &rest args)
  "Call nerd-icons FN with NAME and ARGS, returning empty string if unavailable."
  (if (fboundp fn)
      (apply fn name args)
    ""))

;;; ── Faces ──────────────────────────────────────────────────────────────────

(defgroup workbench-dashboard nil
  "Faces for the workbench project dashboard."
  :group 'workbench)

(defface workbench-dashboard-heading
  '((t :inherit bold :height 1.2))
  "Face for dashboard section headings."
  :group 'workbench-dashboard)

(defface workbench-dashboard-project-name
  '((t :inherit bold :height 1.4))
  "Face for the project name."
  :group 'workbench-dashboard)

(defface workbench-dashboard-path
  '((t :inherit shadow))
  "Face for the project path."
  :group 'workbench-dashboard)

(defface workbench-dashboard-branch
  '((t :inherit font-lock-constant-face :weight bold))
  "Face for the git branch name."
  :group 'workbench-dashboard)

(defface workbench-dashboard-clean
  '((t :inherit success))
  "Face for clean git status."
  :group 'workbench-dashboard)

(defface workbench-dashboard-dirty
  '((t :inherit warning))
  "Face for dirty git status."
  :group 'workbench-dashboard)

(defface workbench-dashboard-commit-hash
  '((t :inherit font-lock-comment-face))
  "Face for commit hashes."
  :group 'workbench-dashboard)

(defface workbench-dashboard-commit-msg
  '((t :inherit default))
  "Face for commit messages."
  :group 'workbench-dashboard)

(defface workbench-dashboard-commit-time
  '((t :inherit shadow))
  "Face for commit relative time."
  :group 'workbench-dashboard)

(defface workbench-dashboard-bar
  '((t :inherit font-lock-function-name-face))
  "Face for language bar characters."
  :group 'workbench-dashboard)

(defface workbench-dashboard-key
  '((t :inherit font-lock-keyword-face :weight bold))
  "Face for action keybinding hints."
  :group 'workbench-dashboard)

(defface workbench-dashboard-separator
  '((t :inherit shadow))
  "Face for section separators."
  :group 'workbench-dashboard)

;;; ── Primitives ─────────────────────────────────────────────────────────────

(defvar workbench--dashboard-bar-width 20
  "Character width of language percentage bars.")

(defun workbench--dashboard-separator ()
  "Insert a visual separator."
  (insert (propertize "  ─────────────────────────────────────────\n"
                      'face 'workbench-dashboard-separator)))

(defun workbench--dashboard-render-heading (icon text)
  "Insert ICON and TEXT as a section heading."
  (insert "  " icon " " (propertize text 'face 'workbench-dashboard-heading) "\n"))

;;; ── Section Renderers ──────────────────────────────────────────────────────

(defun workbench--dashboard-render-overview (data)
  "Render the overview section from DATA plist."
  (insert "\n")
  (insert "  " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-repo" :face 'workbench-dashboard-project-name)
          " " (propertize (plist-get data :name) 'face 'workbench-dashboard-project-name) "\n")
  (insert "  " (propertize (plist-get data :path) 'face 'workbench-dashboard-path) "\n")
  (when-let ((desc (plist-get data :description)))
    (insert "  " (propertize desc 'face 'shadow) "\n"))
  (insert "\n")
  (let ((size (plist-get data :size))
        (contribs (plist-get data :contributors)))
    (when (or size contribs)
      (insert "  ")
      (when size
        (insert (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-file") " "
                (propertize (format "%d files" (plist-get size :files)) 'face 'shadow))
        (when (> (plist-get size :lines) 0)
          (insert (propertize (format ", %dk lines" (/ (plist-get size :lines) 1000))
                              'face 'shadow))))
      (when contribs
        (when size (insert "    "))
        (insert (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-people") " ")
        (let ((first t))
          (dolist (c contribs)
            (unless first (insert (propertize ", " 'face 'shadow)))
            (when (string-match "\\`\\s-*[0-9]+\t\\(.+\\)" c)
              (insert (propertize (match-string 1 c) 'face 'shadow)))
            (setq first nil))))
      (insert "\n")))
  (insert "\n"))

(defun workbench--dashboard-render-git (data)
  "Render the git section from DATA plist."
  (workbench--dashboard-separator)
  (workbench--dashboard-render-heading (workbench--dashboard-icon 'nerd-icons-devicon "nf-dev-git_branch") "Git")
  (if (not data)
      (insert "    " (propertize "not a git repository" 'face 'shadow) "\n\n")
    (insert "    " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-git_branch")
            " " (propertize (plist-get data :branch) 'face 'workbench-dashboard-branch))
    (let ((mod (plist-get data :modified))
          (unt (plist-get data :untracked)))
      (if (and (zerop mod) (zerop unt))
          (insert "  " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-check" :face 'workbench-dashboard-clean)
                  " " (propertize "clean" 'face 'workbench-dashboard-clean))
        (insert "  " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-dot_fill" :face 'workbench-dashboard-dirty)
                " " (propertize (format "%d modified" mod) 'face 'workbench-dashboard-dirty))
        (when (> unt 0)
          (insert (propertize (format " +%d untracked" unt) 'face 'shadow)))))
    (insert "\n")
    (let ((ahead (plist-get data :ahead))
          (behind (plist-get data :behind)))
      (when (or (> ahead 0) (> behind 0))
        (insert "    "
                (workbench--dashboard-icon 'nerd-icons-codicon "nf-cod-arrow_up") (format " %d  " ahead)
                (workbench--dashboard-icon 'nerd-icons-codicon "nf-cod-arrow_down") (format " %d" behind)
                "\n")))
    (when-let ((commit (plist-get data :last-commit)))
      (insert "    " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-git_commit") " "
              (if (string-match "\\([a-f0-9]+\\) \\(.*\\) (\\(.*\\))" commit)
                  (concat (propertize (match-string 1 commit) 'face 'workbench-dashboard-commit-hash)
                          " " (propertize (match-string 2 commit) 'face 'workbench-dashboard-commit-msg)
                          " " (propertize (concat "(" (match-string 3 commit) ")") 'face 'workbench-dashboard-commit-time))
                commit)
              "\n"))
    (insert "\n")))

(defun workbench--dashboard-render-languages (data)
  "Render language breakdown from DATA alist."
  (when data
    (workbench--dashboard-separator)
    (workbench--dashboard-render-heading (workbench--dashboard-icon 'nerd-icons-faicon "nf-fa-code") "Languages")
    (let ((total (float (apply #'+ (mapcar #'cdr data)))))
      (when (> total 0)
        (dolist (pair data)
          (let* ((pct (round (* 100.0 (/ (cdr pair) total))))
                 (filled (max 1 (round (* workbench--dashboard-bar-width (/ (cdr pair) total)))))
                 (empty (max 0 (- workbench--dashboard-bar-width filled))))
            (insert (format "    .%-8s " (car pair))
                    (propertize (make-string filled ?█) 'face 'workbench-dashboard-bar)
                    (propertize (make-string empty ?░) 'face 'shadow)
                    (format " %3d%%\n" pct))))))
    (insert "\n")))

(defun workbench--dashboard-render-commands (directory)
  "Render available commands for DIRECTORY."
  (when-let ((detected (workbench--dashboard-detect-task-runner directory)))
    (let ((runner (car detected))
          (recipes (cdr detected)))
      (when recipes
        (workbench--dashboard-separator)
        (workbench--dashboard-render-heading
         (workbench--dashboard-icon 'nerd-icons-codicon "nf-cod-terminal")
         (format "Commands (%s)" runner))
        (insert "    ")
        (let ((names (split-string (string-join recipes " ") " " t))
              (first t))
          (dolist (recipe names)
            (unless first
              (insert (propertize " │ " 'face 'workbench-dashboard-separator)))
            (insert (propertize recipe 'face 'font-lock-function-name-face))
            (setq first nil)))
        (insert "\n\n")))))

(defun workbench--dashboard-render-dependencies (data)
  "Render dependencies status from DATA list."
  (when data
    (workbench--dashboard-separator)
    (workbench--dashboard-render-heading (workbench--dashboard-icon 'nerd-icons-codicon "nf-cod-package") "Dependencies")
    (dolist (dep data)
      (let ((ready (plist-get dep :ready))
            (tool (plist-get dep :tool))
            (hint (plist-get dep :hint)))
        (insert "    "
                (if ready
                    (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-check" :face 'workbench-dashboard-clean)
                  (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-x" :face 'workbench-dashboard-dirty))
                " "
                (propertize tool 'face 'font-lock-type-face)
                "  "
                (propertize hint 'face (if ready 'shadow 'workbench-dashboard-dirty))
                "\n")))
    (insert "\n")))

(defun workbench--dashboard-render-cicd (data)
  "Render CI/CD pipeline info from DATA plist."
  (when data
    (workbench--dashboard-separator)
    (workbench--dashboard-render-heading
     (workbench--dashboard-icon 'nerd-icons-codicon "nf-cod-rocket") (format "CI/CD (%s)" (plist-get data :source)))
    (insert "    " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-workflow")
            " " (propertize (plist-get data :pipeline) 'face 'font-lock-constant-face) "\n")
    (when-let ((steps (plist-get data :steps)))
      (insert "    ")
      (let ((first t))
        (dolist (step steps)
          (unless first
            (insert (propertize " → " 'face 'workbench-dashboard-separator)))
          (insert (propertize step 'face 'font-lock-function-name-face))
          (setq first nil)))
      (insert "\n"))
    (when-let ((trigger (plist-get data :trigger)))
      (insert "    " (workbench--dashboard-icon 'nerd-icons-codicon "nf-cod-zap") " "
              (propertize (string-join trigger ", ") 'face 'shadow) "\n"))
    (insert "\n")))

(defun workbench--dashboard-render-recent (data)
  "Render recent activity from DATA plist."
  (when data
    (workbench--dashboard-separator)
    (workbench--dashboard-render-heading (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-history") "Recent")
    (when-let ((commits (plist-get data :commits)))
      (dolist (c commits)
        (insert "    " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-git_commit") " "
                (if (string-match "\\([a-f0-9]+\\) \\(.*\\)" c)
                    (concat (propertize (match-string 1 c) 'face 'workbench-dashboard-commit-hash)
                            " " (match-string 2 c))
                  c)
                "\n")))
    (when-let ((changed (plist-get data :changed)))
      (insert "\n")
      (dolist (f (seq-take changed 10))
        (insert "    " (workbench--dashboard-icon 'nerd-icons-octicon "nf-oct-diff") " "
                (propertize f 'face 'font-lock-string-face) "\n")))
    (insert "\n")))

(defun workbench--dashboard-render-actions (_directory overview)
  "Render the actions footer."
  (workbench--dashboard-separator)
  (insert "\n")
  (let ((actions `(("f" . "files")
                   ("s" . "search")
                   ("g" . "git")
                   ("t" . "term")
                   ("a" . "ai")
                   ("e" . "explorer")
                   ("R" . "refresh")
                   ,@(when (plist-get overview :has-readme)
                       '(("r" . "readme"))))))
    (insert "  ")
    (dolist (action actions)
      (insert " " (propertize (format "[%s]" (car action)) 'face 'workbench-dashboard-key)
              (cdr action)))
    (insert "\n")))

(defun workbench--dashboard-render-readme (directory)
  "Render README content below the dashboard with markdown fontification."
  (let ((readme (cond
                 ((file-exists-p (expand-file-name "README.md" directory))
                  (expand-file-name "README.md" directory))
                 ((file-exists-p (expand-file-name "README.org" directory))
                  (expand-file-name "README.org" directory)))))
    (when readme
      (insert "\n\n")
      (insert (propertize "  ═════════════════════════════════════════\n"
                          'face 'workbench-dashboard-separator))
      (insert "\n")
      (let ((rendered (with-temp-buffer
                        (insert-file-contents readme nil 0 4000)
                        (if (string-suffix-p ".org" readme)
                            (org-mode)
                          (when (fboundp 'markdown-mode)
                            (markdown-mode)
                            (font-lock-ensure)))
                        (buffer-string))))
        (insert rendered)
        (unless (string-suffix-p "\n" rendered)
          (insert "\n"))))))
