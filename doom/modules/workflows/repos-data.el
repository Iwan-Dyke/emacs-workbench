;;; workflows/repos-data.el -*- lexical-binding: t; -*-

;; Data collection for the repos workspace: scanning, status, filtering, sorting.
;; Mirrors grafft's core layer (scanner.py, git.py, models.py, filters.py).

(require 'seq)
(require 'cl-lib)

;;; ── Config ─────────────────────────────────────────────────────────────────

(defvar workbench-repos-roots nil
  "List of root directories to scan for git repos.
Falls back to `workbench-jira-code-root' if nil.")

(defvar workbench-repos-ignore
  '("node_modules" ".venv" "venv" "__pycache__" ".tox" ".mypy_cache"
    ".ruff_cache" ".pytest_cache" "dist" "build" ".eggs" "site-packages"
    ".cargo" ".rustup" "target" ".local" ".emacs.d")
  "Directory names to skip during scanning.")

;;; ── Shell helper ───────────────────────────────────────────────────────────

(defun workbench-repos--shell (dir &rest args)
  "Run ARGS in DIR, return trimmed stdout or nil on failure."
  (let ((default-directory (expand-file-name (or dir "~/"))))
    (with-temp-buffer
      (when (zerop (apply #'call-process (car args) nil t nil (cdr args)))
        (let ((output (string-trim (buffer-string))))
          (unless (string-empty-p output) output))))))

;;; ── Scanner ────────────────────────────────────────────────────────────────

(defun workbench-repos--scan-roots (roots)
  "Scan ROOTS for directories containing .git. Returns list of paths.
Stops descending once a .git is found (no nested repo discovery).
Skips directories listed in `workbench-repos-ignore'."
  (let ((found '())
        (seen (make-hash-table :test 'equal)))
    (dolist (root roots)
      (let ((expanded (expand-file-name root)))
        (when (file-directory-p expanded)
          (setq found (workbench-repos--walk expanded found seen)))))
    (nreverse found)))

(defun workbench-repos--walk (directory found seen)
  "Recursively walk DIRECTORY looking for .git dirs.
Returns FOUND with any new repos prepended. SEEN prevents cycles."
  (let ((resolved (file-truename directory)))
    (if (gethash resolved seen)
        found  ; already visited
      (puthash resolved t seen)
      (if (file-directory-p (expand-file-name ".git" directory))
          ;; Found a repo — add it and stop descending
          (cons resolved found)
        ;; Not a repo — scan children
        (condition-case nil
            (let ((entries (directory-files directory t "^[^.]" t)))
              (dolist (entry entries)
                (when (and (file-directory-p entry)
                           (not (file-symlink-p entry))
                           (not (member (file-name-nondirectory entry)
                                        workbench-repos-ignore)))
                  (setq found (workbench-repos--walk entry found seen))))
              found)
          (file-error found))))))

;;; ── Status ─────────────────────────────────────────────────────────────────

(defun workbench-repos--repo-status (path)
  "Get git status plist for repo at PATH."
  (let* ((name (file-name-nondirectory (directory-file-name path)))
         (branch (or (workbench-repos--shell path "git" "branch" "--show-current") ""))
         (porcelain (workbench-repos--shell path "git" "status" "--porcelain"))
         (ab (workbench-repos--shell path "git" "rev-list" "--left-right" "--count" "HEAD...@{upstream}"))
         (last-commit (workbench-repos--shell path "git" "log" "-1" "--format=%ar"))
         (stash-output (workbench-repos--shell path "git" "stash" "list"))
         (dirty-lines (when porcelain (split-string porcelain "\n" t)))
         (dirty-count (length (or dirty-lines '())))
         (state (if (> dirty-count 0) 'dirty 'clean))
         (ahead 0) (behind 0))
    (when (and ab (string-match "\\([0-9]+\\)\t\\([0-9]+\\)" ab))
      (setq ahead (string-to-number (match-string 1 ab))
            behind (string-to-number (match-string 2 ab))))
    (list :name name
          :path path
          :branch (if (string-empty-p branch) "(detached)" branch)
          :state state
          :dirty dirty-count
          :ahead ahead
          :behind behind
          :last-commit (or last-commit "")
          :stash (if stash-output (length (split-string stash-output "\n" t)) 0))))

(defun workbench-repos--get-all-statuses (paths)
  "Get status for all PATHS. Returns list of status plists."
  (mapcar #'workbench-repos--repo-status paths))

;;; ── Filtering ──────────────────────────────────────────────────────────────

(defun workbench-repos--filter (filter-type repos)
  "Filter REPOS by FILTER-TYPE. Returns filtered list.
FILTER-TYPE is one of: all, dirty, clean, behind, ahead."
  (pcase filter-type
    ('all repos)
    ('dirty (seq-filter (lambda (r) (eq (plist-get r :state) 'dirty)) repos))
    ('clean (seq-filter (lambda (r) (eq (plist-get r :state) 'clean)) repos))
    ('behind (seq-filter (lambda (r) (> (plist-get r :behind) 0)) repos))
    ('ahead (seq-filter (lambda (r) (> (plist-get r :ahead) 0)) repos))
    (_ repos)))

(defvar workbench-repos-filter-names '(all dirty clean behind ahead)
  "Available filter names in cycle order.")

;;; ── Sorting ────────────────────────────────────────────────────────────────

(defun workbench-repos--sort (sort-type repos)
  "Sort REPOS by SORT-TYPE. Returns sorted copy.
SORT-TYPE is one of: name, status, dirty."
  (let ((copy (copy-sequence repos)))
    (pcase sort-type
      ('name
       (sort copy (lambda (a b)
                    (string< (plist-get a :name) (plist-get b :name)))))
      ('status
       (sort copy (lambda (a b)
                    (> (workbench-repos--status-priority a)
                       (workbench-repos--status-priority b)))))
      ('dirty
       (sort copy (lambda (a b)
                    (> (plist-get a :dirty) (plist-get b :dirty)))))
      (_ copy))))

(defun workbench-repos--status-priority (repo)
  "Return sort priority for REPO. Higher = more attention needed."
  (let ((state (plist-get repo :state))
        (behind (plist-get repo :behind)))
    (cond
     ((eq state 'dirty) 30)
     ((> behind 0) 20)
     (t 10))))

(defvar workbench-repos-sort-names '(name status dirty)
  "Available sort names in cycle order.")

;;; ── Search ─────────────────────────────────────────────────────────────────

(defun workbench-repos--search (query repos)
  "Filter REPOS whose name matches QUERY (case-insensitive substring)."
  (if (or (null query) (string-empty-p query))
      repos
    (let ((q (downcase query)))
      (seq-filter (lambda (r)
                    (string-match-p (regexp-quote q)
                                    (downcase (plist-get r :name))))
                  repos))))

;;; ── Pull eligibility ───────────────────────────────────────────────────────

(defun workbench-repos--pullable (repos)
  "Return repos from REPOS that are clean and behind remote."
  (seq-filter (lambda (r)
                (and (eq (plist-get r :state) 'clean)
                     (> (plist-get r :behind) 0)))
              repos))

;;; ── Fetch/Pull operations ──────────────────────────────────────────────────

(defun workbench-repos--fetch (path)
  "Run git fetch on repo at PATH. Returns t on success, nil on failure."
  (not (null (workbench-repos--shell path "git" "fetch" "--quiet"))))

(defun workbench-repos--pull (path)
  "Run git pull --ff-only on repo at PATH. Returns (t) or (nil . error-msg)."
  (let ((default-directory (expand-file-name path)))
    (with-temp-buffer
      (let ((exit (call-process "git" nil t nil "pull" "--ff-only")))
        (if (zerop exit)
            '(t)
          (cons nil (string-trim (buffer-string))))))))

(provide 'workbench-repos-data)
;;; repos-data.el ends here
