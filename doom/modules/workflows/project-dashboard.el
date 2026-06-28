;;; workflows/project-dashboard.el -*- lexical-binding: t; -*-

(declare-function workbench--directory-name "modules/tools/files")
(declare-function workbench--project-root "modules/tools/files")
(declare-function workbench/open-files "modules/tools/files")
(declare-function workbench/open-project-tree "modules/tools/files")
(declare-function workbench/toggle-project-ai "modules/workflows/ai")

(require 'nerd-icons nil t)

;;; Faces

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

(defun workbench--dashboard-description (directory)
  "Extract a one-line description from README or project config in DIRECTORY."
  (or
   ;; pyproject.toml description
   (let ((pyproject (expand-file-name "pyproject.toml" directory)))
     (when (file-exists-p pyproject)
       (with-temp-buffer
         (insert-file-contents pyproject)
         (when (re-search-forward "^description\\s-*=\\s-*\"\\(.+?\\)\"" nil t)
           (match-string 1)))))
   ;; package.json description
   (let ((pkg (expand-file-name "package.json" directory)))
     (when (file-exists-p pkg)
       (with-temp-buffer
         (insert-file-contents pkg)
         (when (re-search-forward "\"description\"\\s-*:\\s-*\"\\(.+?\\)\"" nil t)
           (match-string 1)))))
   ;; First meaningful line from README
   (let ((readme (cond
                  ((file-exists-p (expand-file-name "README.md" directory))
                   (expand-file-name "README.md" directory))
                  ((file-exists-p (expand-file-name "README.org" directory))
                   (expand-file-name "README.org" directory)))))
     (when readme
       (with-temp-buffer
         (insert-file-contents readme nil 0 2000)
         (goto-char (point-min))
         (let (found)
           (while (and (not found) (not (eobp)))
             (let ((line (string-trim (thing-at-point 'line t))))
               (when (and (not (string-empty-p line))
                          (not (string-prefix-p "#" line))
                          (not (string-prefix-p "=" line))
                          (not (string-prefix-p "*" line))
                          (not (string-prefix-p "[" line))
                          (not (string-prefix-p "!" line)))
                 (setq found (truncate-string-to-width line 80))))
             (forward-line 1))
           found))))))

(defun workbench--dashboard-size (directory)
  "Get file count and line count for DIRECTORY via git ls-files."
  (when (workbench--dashboard-git-p directory)
    (when-let ((files (workbench--dashboard-shell-lines directory "git" "ls-files")))
      (list :files (length files)
            :lines (string-to-number
                    (or (workbench--dashboard-shell directory
                          "sh" "-c" "git ls-files | xargs wc -l 2>/dev/null | tail -1 | awk '{print $1}'")
                        "0"))))))

(defun workbench--dashboard-contributors (directory)
  "Get top 3 contributors by commit count in DIRECTORY."
  (when (workbench--dashboard-git-p directory)
    (workbench--dashboard-shell-lines directory
      "git" "shortlog" "-sn" "--no-merges" "HEAD")))

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
          :description (workbench--dashboard-description directory)
          :size (workbench--dashboard-size directory)
          :contributors (seq-take (workbench--dashboard-contributors directory) 3)
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

(defun workbench--dashboard-dependencies (directory)
  "Collect dependency/environment status for DIRECTORY."
  (let (items)
    ;; Python
    (when (file-exists-p (expand-file-name "pyproject.toml" directory))
      (let* ((venv (expand-file-name ".venv" directory))
             (has-venv (file-directory-p venv)))
        (push (list :tool "python"
                    :file "pyproject.toml"
                    :ready has-venv
                    :hint (if has-venv ".venv" "run: uv sync"))
              items)))
    ;; Node
    (when (file-exists-p (expand-file-name "package.json" directory))
      (let ((has-nm (file-directory-p (expand-file-name "node_modules" directory))))
        (push (list :tool "node"
                    :file "package.json"
                    :ready has-nm
                    :hint (if has-nm "node_modules" "run: npm install"))
              items)))
    ;; Go
    (when (file-exists-p (expand-file-name "go.mod" directory))
      (push (list :tool "go" :file "go.mod" :ready t :hint "modules") items))
    ;; Rust
    (when (file-exists-p (expand-file-name "Cargo.toml" directory))
      (let ((has-target (file-directory-p (expand-file-name "target" directory))))
        (push (list :tool "rust"
                    :file "Cargo.toml"
                    :ready has-target
                    :hint (if has-target "target" "run: cargo build"))
              items)))
    ;; Terraform
    (when (file-directory-p (expand-file-name ".terraform" directory))
      (push (list :tool "terraform" :file ".terraform" :ready t :hint "initialised") items))
    (nreverse items)))

(defun workbench--dashboard-cicd (directory)
  "Parse .drone.yml in DIRECTORY. Returns plist or nil."
  (let ((drone-file (expand-file-name ".drone.yml" directory)))
    (when (file-exists-p drone-file)
      (condition-case nil
          (let* ((content (with-temp-buffer
                            (insert-file-contents drone-file)
                            (buffer-string)))
                 (pipeline-name nil)
                 (steps nil)
                 (trigger nil))
            ;; Parse pipeline name
            (when (string-match "^name:\\s-*\\(.+\\)" content)
              (setq pipeline-name (string-trim (match-string 1 content))))
            ;; Parse step names
            (let ((pos 0))
              (while (string-match "^  - name:\\s-*\\(.+\\)" content pos)
                (push (string-trim (match-string 1 content)) steps)
                (setq pos (match-end 0))))
            ;; Parse trigger events
            (when (string-match "^trigger:\n\\(?:  .*\n\\)*?  event:\n\\(\\(?:    .*\n?\\)+\\)" content)
              (let ((block (match-string 1 content))
                    (tpos 0))
                (while (string-match "- \\(.+\\)" block tpos)
                  (push (string-trim (match-string 1 block)) trigger)
                  (setq tpos (match-end 0)))))
            (list :source ".drone.yml"
                  :pipeline (or pipeline-name "default")
                  :steps (nreverse steps)
                  :trigger (nreverse trigger)))
        (error nil)))))

(defun workbench--dashboard-recent (directory)
  "Collect recent activity for DIRECTORY."
  (when (workbench--dashboard-git-p directory)
    (list :commits (workbench--dashboard-shell-lines directory
                     "git" "log" "--oneline" "-5")
          :changed (workbench--dashboard-shell-lines directory
                     "git" "diff" "--name-only" "HEAD"))))


;;; Rendering

(defvar workbench--dashboard-bar-width 20
  "Character width of language percentage bars.")

(defun workbench--dashboard-separator ()
  "Insert a visual separator."
  (insert (propertize "  ─────────────────────────────────────────\n"
                      'face 'workbench-dashboard-separator)))

(defun workbench--dashboard-render-heading (icon text)
  "Insert ICON and TEXT as a section heading."
  (insert "  " icon " " (propertize text 'face 'workbench-dashboard-heading) "\n"))

(defun workbench--dashboard-render-overview (data)
  "Render the overview section from DATA plist."
  (insert "\n")
  (insert "  " (nerd-icons-octicon "nf-oct-repo" :face 'workbench-dashboard-project-name)
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
        (insert (nerd-icons-octicon "nf-oct-file") " "
                (propertize (format "%d files" (plist-get size :files)) 'face 'shadow))
        (when (> (plist-get size :lines) 0)
          (insert (propertize (format ", %dk lines" (/ (plist-get size :lines) 1000))
                              'face 'shadow))))
      (when contribs
        (when size (insert "    "))
        (insert (nerd-icons-octicon "nf-oct-people") " ")
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
  (workbench--dashboard-render-heading (nerd-icons-devicon "nf-dev-git_branch") "Git")
  (if (not data)
      (insert "    " (propertize "not a git repository" 'face 'shadow) "\n\n")
    (insert "    " (nerd-icons-octicon "nf-oct-git_branch")
            " " (propertize (plist-get data :branch) 'face 'workbench-dashboard-branch))
    (let ((mod (plist-get data :modified))
          (unt (plist-get data :untracked)))
      (if (and (zerop mod) (zerop unt))
          (insert "  " (nerd-icons-octicon "nf-oct-check" :face 'workbench-dashboard-clean)
                  " " (propertize "clean" 'face 'workbench-dashboard-clean))
        (insert "  " (nerd-icons-octicon "nf-oct-dot_fill" :face 'workbench-dashboard-dirty)
                " " (propertize (format "%d modified" mod) 'face 'workbench-dashboard-dirty))
        (when (> unt 0)
          (insert (propertize (format " +%d untracked" unt) 'face 'shadow)))))
    (insert "\n")
    (let ((ahead (plist-get data :ahead))
          (behind (plist-get data :behind)))
      (when (or (> ahead 0) (> behind 0))
        (insert "    "
                (nerd-icons-codicon "nf-cod-arrow_up") (format " %d  " ahead)
                (nerd-icons-codicon "nf-cod-arrow_down") (format " %d" behind)
                "\n")))
    (when-let ((commit (plist-get data :last-commit)))
      (insert "    " (nerd-icons-octicon "nf-oct-git_commit") " "
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
    (workbench--dashboard-render-heading (nerd-icons-faicon "nf-fa-code") "Languages")
    (let ((total (float (apply #'+ (mapcar #'cdr data)))))
      (dolist (pair data)
        (let* ((pct (round (* 100.0 (/ (cdr pair) total))))
               (filled (max 1 (round (* workbench--dashboard-bar-width (/ (cdr pair) total)))))
               (empty (max 0 (- workbench--dashboard-bar-width filled))))
          (insert (format "    .%-8s " (car pair))
                  (propertize (make-string filled ?█) 'face 'workbench-dashboard-bar)
                  (propertize (make-string empty ?░) 'face 'shadow)
                  (format " %3d%%\n" pct)))))
    (insert "\n")))

(defun workbench--dashboard-detect-task-runner (directory)
  "Detect the task runner in DIRECTORY. Returns (name . recipes) or nil."
  (cond
   ((file-exists-p (expand-file-name "justfile" directory))
    (cons "justfile" (workbench--dashboard-commands-justfile directory)))
   ((file-exists-p (expand-file-name "Makefile" directory))
    (cons "Makefile" (workbench--dashboard-shell-lines directory
                       "make" "-pRrq" "--no-print-directory")))))

(defun workbench--dashboard-render-commands (directory)
  "Render available commands for DIRECTORY."
  (when-let ((detected (workbench--dashboard-detect-task-runner directory)))
    (let ((runner (car detected))
          (recipes (cdr detected)))
      (when recipes
        (workbench--dashboard-separator)
        (workbench--dashboard-render-heading
         (nerd-icons-codicon "nf-cod-terminal")
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
    (workbench--dashboard-render-heading (nerd-icons-codicon "nf-cod-package") "Dependencies")
    (dolist (dep data)
      (let ((ready (plist-get dep :ready))
            (tool (plist-get dep :tool))
            (hint (plist-get dep :hint)))
        (insert "    "
                (if ready
                    (nerd-icons-octicon "nf-oct-check" :face 'workbench-dashboard-clean)
                  (nerd-icons-octicon "nf-oct-x" :face 'workbench-dashboard-dirty))
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
     (nerd-icons-codicon "nf-cod-rocket") (format "CI/CD (%s)" (plist-get data :source)))
    (insert "    " (nerd-icons-octicon "nf-oct-workflow")
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
      (insert "    " (nerd-icons-codicon "nf-cod-zap") " "
              (propertize (string-join trigger ", ") 'face 'shadow) "\n"))
    (insert "\n")))

(defun workbench--dashboard-render-recent (data)
  "Render recent activity from DATA plist."
  (when data
    (workbench--dashboard-separator)
    (workbench--dashboard-render-heading (nerd-icons-octicon "nf-oct-history") "Recent")
    (when-let ((commits (plist-get data :commits)))
      (dolist (c commits)
        (insert "    " (nerd-icons-octicon "nf-oct-git_commit") " "
                (if (string-match "\\([a-f0-9]+\\) \\(.*\\)" c)
                    (concat (propertize (match-string 1 c) 'face 'workbench-dashboard-commit-hash)
                            " " (match-string 2 c))
                  c)
                "\n")))
    (when-let ((changed (plist-get data :changed)))
      (insert "\n")
      (dolist (f (seq-take changed 10))
        (insert "    " (nerd-icons-octicon "nf-oct-diff") " "
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

;;; Keymap

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

;;; Entry points

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
  "Refresh the current project dashboard."
  (interactive)
  (when (bound-and-true-p workbench--dashboard-directory)
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
         (project-identity (workbench--project-identity-name project-directory))
         (buffer (get-buffer-create (format "*workbench:%s*" project-identity)))
         (overview (workbench--dashboard-overview project-directory))
         (git (workbench--dashboard-git project-directory))
         (languages (workbench--dashboard-languages project-directory))
         (deps (workbench--dashboard-dependencies project-directory))
         (cicd (workbench--dashboard-cicd project-directory))
         (recent (workbench--dashboard-recent project-directory)))
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
    (setq-local workbench--dashboard-directory project-directory)))

(provide 'workbench-project-dashboard)
