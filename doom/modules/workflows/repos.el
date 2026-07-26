;;; workflows/repos.el -*- lexical-binding: t; -*-

;; Multi-repo operations dashboard (ADR 0040).
;; Text-based buffer showing all repos under configured roots with status,
;; filtering, sorting, fetch, and pull. Emacs equivalent of grafft TUI.

(require 'seq)
(require 'cl-lib)

(unless (fboundp 'workbench-repos--scan-roots)
  (load! "repos-data"))

(declare-function workbench/open-project-workspace "modules/workflows/coding")
(declare-function workbench/toggle-popup-magit "modules/tools/git")

;;; ── State ──────────────────────────────────────────────────────────────────

(defvar workbench-repos--buffer-name "*repos*"
  "Name of the repos dashboard buffer.")

(defvar workbench-repos--statuses nil
  "Cached list of repo status plists.")

(defvar workbench-repos--current-filter 'all
  "Current filter applied to the repos view.")

(defvar workbench-repos--current-sort 'name
  "Current sort applied to the repos view.")

(defvar workbench-repos--current-search ""
  "Current search string for filtering repos.")

;;; ── Faces ──────────────────────────────────────────────────────────────────

(defface workbench-repos-clean
  '((t :inherit success))
  "Face for clean repo status indicators.")

(defface workbench-repos-dirty
  '((t :inherit warning))
  "Face for dirty repo status indicators.")

(defface workbench-repos-behind
  '((t :inherit error))
  "Face for repos behind remote.")

(defface workbench-repos-branch
  '((t :inherit font-lock-constant-face))
  "Face for branch names.")

(defface workbench-repos-name
  '((t :inherit bold))
  "Face for repo names.")

(defface workbench-repos-dim
  '((t :inherit shadow))
  "Face for secondary information.")

;;; ── Rendering ──────────────────────────────────────────────────────────────

(defun workbench-repos--render (repos)
  "Render REPOS into the *repos* buffer. Returns the buffer."
  (let ((buf (get-buffer-create workbench-repos--buffer-name)))
    (with-current-buffer buf
      (let ((inhibit-read-only t))
        (erase-buffer)
        (if (null repos)
            (workbench-repos--render-empty)
          (workbench-repos--render-header repos)
          (workbench-repos--render-toolbar)
          (insert "\n")
          (dolist (repo repos)
            (workbench-repos--render-repo-line repo))
          (insert "\n")
          (workbench-repos--render-footer)))
      (goto-char (point-min))
      (workbench-repos-mode))
    buf))

(defun workbench-repos--render-empty ()
  "Render empty state message."
  (insert "\n")
  (insert "  " (propertize "No repos found" 'face 'shadow) "\n\n")
  (insert "  Configure roots in profiles/local.el:\n")
  (insert "    (setq workbench-repos-roots '(\"~/code/\"))\n"))

(defun workbench-repos--render-header (repos)
  "Render the summary header for REPOS."
  (let* ((total (length repos))
         (dirty (cl-count-if (lambda (r) (eq (plist-get r :state) 'dirty)) repos))
         (behind (cl-count-if (lambda (r) (> (plist-get r :behind) 0)) repos))
         (ahead (cl-count-if (lambda (r) (> (plist-get r :ahead) 0)) repos)))
    (insert "\n")
    (insert "  " (propertize "REPOS" 'face '(:weight bold :height 1.2)) "  ")
    (insert (propertize (format "%d repos" total) 'face 'default))
    (when (> dirty 0)
      (insert "  " (propertize (format "%d dirty" dirty) 'face 'workbench-repos-dirty)))
    (when (> behind 0)
      (insert "  " (propertize (format "%d behind" behind) 'face 'workbench-repos-behind)))
    (when (> ahead 0)
      (insert "  " (propertize (format "%d ahead" ahead) 'face 'workbench-repos-dim)))
    (insert "\n")))

(defun workbench-repos--render-toolbar ()
  "Render the filter/sort toolbar."
  (insert "  "
          (propertize "Filter:" 'face 'shadow) " "
          (propertize (symbol-name workbench-repos--current-filter)
                      'face 'font-lock-keyword-face)
          "  "
          (propertize "Sort:" 'face 'shadow) " "
          (propertize (symbol-name workbench-repos--current-sort)
                      'face 'font-lock-keyword-face))
  (when (not (string-empty-p workbench-repos--current-search))
    (insert "  "
            (propertize "Search:" 'face 'shadow) " "
            (propertize workbench-repos--current-search
                        'face 'font-lock-keyword-face)))
  (insert "\n"))

(defun workbench-repos--render-repo-line (repo)
  "Render a single REPO status line."
  (let* ((name (plist-get repo :name))
         (path (plist-get repo :path))
         (branch (plist-get repo :branch))
         (state (plist-get repo :state))
         (dirty (plist-get repo :dirty))
         (ahead (plist-get repo :ahead))
         (behind (plist-get repo :behind))
         (last-commit (plist-get repo :last-commit))
         (stash (plist-get repo :stash))
         (state-face (if (eq state 'clean) 'workbench-repos-clean 'workbench-repos-dirty))
         (pip (if (eq state 'clean) "●" "●"))
         (line-start (point)))
    ;; Status pip
    (insert "  " (propertize pip 'face state-face) " ")
    ;; Repo name (padded)
    (insert (propertize (truncate-string-to-width name 25) 'face 'workbench-repos-name) " ")
    ;; Branch
    (insert (propertize (truncate-string-to-width branch 25) 'face 'workbench-repos-branch) " ")
    ;; Status indicators
    (if (eq state 'clean)
        (insert (propertize "✓" 'face 'workbench-repos-clean) " ")
      (insert (propertize (format "%d changed" dirty) 'face 'workbench-repos-dirty) " "))
    ;; Ahead/behind
    (when (> ahead 0)
      (insert (propertize (format "↑%d" ahead) 'face 'workbench-repos-dim) " "))
    (when (> behind 0)
      (insert (propertize (format "↓%d" behind) 'face 'workbench-repos-behind) " "))
    ;; Stash
    (when (and stash (> stash 0))
      (insert (propertize (format "⚑%d" stash) 'face 'workbench-repos-dim) " "))
    ;; Last commit
    (insert (propertize (or last-commit "") 'face 'workbench-repos-dim))
    (insert "\n")
    ;; Apply path property to entire line for navigation
    (put-text-property line-start (point) 'workbench-repos-path path)))

(defun workbench-repos--render-footer ()
  "Render the keybinding footer."
  (insert "  "
          (propertize "[r]" 'face 'font-lock-keyword-face) "efresh  "
          (propertize "[f]" 'face 'font-lock-keyword-face) "ilter  "
          (propertize "[s]" 'face 'font-lock-keyword-face) "ort  "
          (propertize "[u]" 'face 'font-lock-keyword-face) "pdate  "
          (propertize "[p]" 'face 'font-lock-keyword-face) "ull  "
          (propertize "[P]" 'face 'font-lock-keyword-face) "ull all  "
          (propertize "[/]" 'face 'font-lock-keyword-face) "search  "
          (propertize "[RET]" 'face 'font-lock-keyword-face) " open  "
          (propertize "[g]" 'face 'font-lock-keyword-face) "it  "
          (propertize "[q]" 'face 'font-lock-keyword-face) "uit\n"))

;;; ── Mode ───────────────────────────────────────────────────────────────────

(defvar workbench-repos-mode-map
  (let ((map (make-sparse-keymap)))
    (define-key map "r" #'workbench-repos-refresh)
    (define-key map "f" #'workbench-repos-cycle-filter)
    (define-key map "s" #'workbench-repos-cycle-sort)
    (define-key map "u" #'workbench-repos-fetch-all)
    (define-key map "p" #'workbench-repos-pull-selected)
    (define-key map "P" #'workbench-repos-pull-all)
    (define-key map "/" #'workbench-repos-search)
    (define-key map (kbd "RET") #'workbench-repos-open-project)
    (define-key map "g" #'workbench-repos-magit)
    (define-key map "q" #'quit-window)
    (define-key map "j" #'next-line)
    (define-key map "k" #'previous-line)
    map)
  "Keymap for repos dashboard.")

(define-derived-mode workbench-repos-mode special-mode "Repos"
  "Major mode for the workbench repos dashboard."
  (setq-local cursor-type nil)
  (setq-local truncate-lines t)
  (setq-local buffer-read-only t))

(after! evil
  (evil-set-initial-state 'workbench-repos-mode 'normal)
  (evil-define-key 'normal workbench-repos-mode-map
    "r" #'workbench-repos-refresh
    "f" #'workbench-repos-cycle-filter
    "s" #'workbench-repos-cycle-sort
    "u" #'workbench-repos-fetch-all
    "p" #'workbench-repos-pull-selected
    "P" #'workbench-repos-pull-all
    "/" #'workbench-repos-search
    (kbd "RET") #'workbench-repos-open-project
    "g" #'workbench-repos-magit
    "q" #'quit-window
    "j" #'next-line
    "k" #'previous-line))

;;; ── Commands ───────────────────────────────────────────────────────────────

(defun workbench-repos--roots ()
  "Return the configured roots to scan."
  (or workbench-repos-roots
      (list (expand-file-name (or (bound-and-true-p workbench-jira-code-root) "~/code/")))))

(defun workbench-repos--filtered-view ()
  "Return the current view: filtered, sorted, searched."
  (let* ((filtered (workbench-repos--filter workbench-repos--current-filter
                                            workbench-repos--statuses))
         (searched (workbench-repos--search workbench-repos--current-search filtered))
         (sorted (workbench-repos--sort workbench-repos--current-sort searched)))
    sorted))

(defun workbench-repos--redraw ()
  "Redraw the repos buffer from cached data."
  (when workbench-repos--statuses
    (workbench-repos--render (workbench-repos--filtered-view))))

(defun workbench-repos-refresh ()
  "Rescan and refresh all repo statuses."
  (interactive)
  (message "Repos: scanning...")
  (let ((paths (workbench-repos--scan-roots (workbench-repos--roots))))
    (setq workbench-repos--statuses (workbench-repos--get-all-statuses paths))
    (workbench-repos--redraw)
    (message "Repos: %d repos found" (length workbench-repos--statuses))))

(defun workbench-repos-cycle-filter ()
  "Cycle to the next filter."
  (interactive)
  (let* ((names workbench-repos-filter-names)
         (idx (cl-position workbench-repos--current-filter names))
         (next (nth (mod (1+ (or idx 0)) (length names)) names)))
    (setq workbench-repos--current-filter next)
    (workbench-repos--redraw)
    (message "Filter: %s" next)))

(defun workbench-repos-cycle-sort ()
  "Cycle to the next sort order."
  (interactive)
  (let* ((names workbench-repos-sort-names)
         (idx (cl-position workbench-repos--current-sort names))
         (next (nth (mod (1+ (or idx 0)) (length names)) names)))
    (setq workbench-repos--current-sort next)
    (workbench-repos--redraw)
    (message "Sort: %s" next)))

(defun workbench-repos-search ()
  "Prompt for a search string and filter repos."
  (interactive)
  (let ((query (read-string "Search repos: " workbench-repos--current-search)))
    (setq workbench-repos--current-search query)
    (workbench-repos--redraw)))

(defun workbench-repos--path-at-point ()
  "Return the repo path at point, or nil."
  (get-text-property (line-beginning-position) 'workbench-repos-path))

(defun workbench-repos-open-project ()
  "Open the repo at point as a project workspace."
  (interactive)
  (if-let ((path (workbench-repos--path-at-point)))
      (workbench/open-project-workspace path)
    (user-error "No repo at point")))

(defun workbench-repos-magit ()
  "Open magit for the repo at point."
  (interactive)
  (if-let ((path (workbench-repos--path-at-point)))
      (let ((default-directory path))
        (workbench/toggle-popup-magit))
    (user-error "No repo at point")))

(defun workbench-repos-fetch-all ()
  "Fetch all repos in background."
  (interactive)
  (message "Repos: fetching remotes...")
  (let ((count 0) (failed 0))
    (dolist (repo workbench-repos--statuses)
      (if (workbench-repos--fetch (plist-get repo :path))
          (cl-incf count)
        (cl-incf failed)))
    ;; Re-read statuses after fetch
    (let ((paths (mapcar (lambda (r) (plist-get r :path)) workbench-repos--statuses)))
      (setq workbench-repos--statuses (workbench-repos--get-all-statuses paths)))
    (workbench-repos--redraw)
    (message "Repos: fetched %d%s"
             count (if (> failed 0) (format " (%d failed)" failed) ""))))

(defun workbench-repos-pull-selected ()
  "Pull the repo at point (only if clean and behind)."
  (interactive)
  (if-let ((path (workbench-repos--path-at-point)))
      (let ((repo (seq-find (lambda (r) (equal (plist-get r :path) path))
                            workbench-repos--statuses)))
        (cond
         ((not repo) (user-error "Repo not found"))
         ((eq (plist-get repo :state) 'dirty)
          (user-error "Cannot pull — repo is dirty"))
         ((= (plist-get repo :behind) 0)
          (message "Already up to date"))
         (t
          (message "Pulling %s..." (plist-get repo :name))
          (let ((result (workbench-repos--pull path)))
            (if (car result)
                (progn
                  (message "Pulled %s" (plist-get repo :name))
                  (workbench-repos-refresh))
              (user-error "Pull failed: %s" (cdr result)))))))
    (user-error "No repo at point")))

(defun workbench-repos-pull-all ()
  "Pull all clean repos that are behind."
  (interactive)
  (let ((pullable (workbench-repos--pullable workbench-repos--statuses)))
    (if (null pullable)
        (message "No repos to pull")
      (message "Pulling %d repos..." (length pullable))
      (let ((pulled 0) (failed 0))
        (dolist (repo pullable)
          (let ((result (workbench-repos--pull (plist-get repo :path))))
            (if (car result)
                (cl-incf pulled)
              (cl-incf failed))))
        (workbench-repos-refresh)
        (message "Pulled %d%s"
                 pulled (if (> failed 0) (format " (%d failed)" failed) ""))))))

;;; ── Entry point ────────────────────────────────────────────────────────────

(defun workbench/open-repos ()
  "Open the repos workspace dashboard."
  (interactive)
  (let ((buf (get-buffer workbench-repos--buffer-name)))
    (if (and buf (buffer-live-p buf) workbench-repos--statuses)
        ;; Already have data — show existing buffer
        (switch-to-buffer buf)
      ;; First open or stale — scan
      (workbench-repos-refresh)
      (switch-to-buffer (get-buffer workbench-repos--buffer-name)))))

(provide 'workbench-repos)
;;; repos.el ends here
