;;; workflows/project-dashboard-data.el -*- lexical-binding: t; -*-

;; Data collection for the project dashboard: shell helpers, git status,
;; overview, languages, dependencies, CI/CD, recent activity.

(declare-function workbench--directory-name "modules/tools/files")

;;; ── Shell Helpers ──────────────────────────────────────────────────────────

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

;;; ── Overview ───────────────────────────────────────────────────────────────

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
                          "sh" "-c" "git ls-files -z | xargs -0 wc -l 2>/dev/null | tail -1 | awk '{print $1}'")
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
               ((file-directory-p (expand-file-name ".terraform" directory)) "terraform")
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

;;; ── Git ────────────────────────────────────────────────────────────────────

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

;;; ── Languages ──────────────────────────────────────────────────────────────

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

;;; ── Commands ───────────────────────────────────────────────────────────────

(defun workbench--dashboard-commands-justfile (directory)
  "Parse justfile recipe names from DIRECTORY."
  (when (file-exists-p (expand-file-name "justfile" directory))
    (workbench--dashboard-shell-lines directory "just" "--summary")))

(defun workbench--dashboard-detect-task-runner (directory)
  "Detect the task runner in DIRECTORY. Returns (name . recipes) or nil."
  (cond
   ((file-exists-p (expand-file-name "justfile" directory))
    (cons "justfile" (workbench--dashboard-commands-justfile directory)))
   ((file-exists-p (expand-file-name "Makefile" directory))
    (cons "Makefile" (workbench--dashboard-shell-lines directory
                       "sh" "-c" "make -pRrq --no-print-directory 2>/dev/null | awk -F: '/^[a-zA-Z0-9][^$#\\/\\t=]*:([^=]|$)/ {split($1,a,\" \"); print a[1]}'")))))

;;; ── Dependencies ───────────────────────────────────────────────────────────

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

;;; ── CI/CD ──────────────────────────────────────────────────────────────────

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

;;; ── Recent Activity ────────────────────────────────────────────────────────

(defun workbench--dashboard-recent (directory)
  "Collect recent activity for DIRECTORY."
  (when (workbench--dashboard-git-p directory)
    (list :commits (workbench--dashboard-shell-lines directory
                     "git" "log" "--oneline" "-5")
          :changed (workbench--dashboard-shell-lines directory
                     "git" "diff" "--name-only" "HEAD"))))
