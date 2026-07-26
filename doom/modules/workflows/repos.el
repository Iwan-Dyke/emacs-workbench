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
          (workbench-repos--render-footer)
          (insert "\n")
          (workbench-repos--render-table repos)))
      ;; Position point on first data row
      (goto-char (point-min))
      (workbench-repos-mode)
      (let ((found nil))
        (while (and (not found) (not (eobp)))
          (when (and (fboundp 'vtable-current-object) (vtable-current-object))
            (setq found t))
          (unless found (forward-line 1)))))
    buf))

(defun workbench-repos--render-empty ()
  "Render empty state message."
  (insert "\n")
  (insert "  " (propertize "No repos found" 'face 'shadow) "\n\n")
  (insert "  Configure roots in profiles/local.el:\n")
  (insert "    (setq workbench-repos-roots '(\"~/code/\"))\n"))

(defun workbench-repos--icon (fn name &optional face)
  "Call nerd-icons FN with NAME, applying FACE. Empty string if unavailable."
  (if (fboundp fn)
      (let ((icon (funcall fn name)))
        (if face (propertize icon 'face face) icon))
    ""))

(defun workbench-repos--separator ()
  "Insert a visual separator."
  (insert "  " (propertize "────────────────────────────────────────────────────────────────\n"
                            'face 'shadow)))

(defun workbench-repos--render-header (repos)
  "Render the summary header for REPOS."
  (let* ((total (length repos))
         (dirty (cl-count-if (lambda (r) (eq (plist-get r :state) 'dirty)) repos))
         (clean (- total dirty))
         (behind (cl-count-if (lambda (r) (> (plist-get r :behind) 0)) repos))
         (ahead (cl-count-if (lambda (r) (> (plist-get r :ahead) 0)) repos))
         (stashed (cl-count-if (lambda (r) (> (or (plist-get r :stash) 0) 0)) repos)))
    (insert "\n")
    (insert "  "
            (workbench-repos--icon 'nerd-icons-octicon "nf-oct-repo" 'font-lock-keyword-face)
            " "
            (propertize "REPOS" 'face '(:weight bold :height 1.3))
            "\n\n")
    ;; Stats line with icons
    (insert "  "
            (propertize (format "%d" total) 'face '(:weight bold))
            (propertize " repos" 'face 'shadow)
            "   "
            (workbench-repos--icon 'nerd-icons-octicon "nf-oct-check" 'workbench-repos-clean)
            " " (propertize (format "%d clean" clean) 'face 'workbench-repos-clean))
    (when (> dirty 0)
      (insert "   "
              (workbench-repos--icon 'nerd-icons-octicon "nf-oct-dot_fill" 'workbench-repos-dirty)
              " " (propertize (format "%d dirty" dirty) 'face 'workbench-repos-dirty)))
    (when (> behind 0)
      (insert "   "
              (workbench-repos--icon 'nerd-icons-codicon "nf-cod-arrow_down" 'workbench-repos-behind)
              " " (propertize (format "%d behind" behind) 'face 'workbench-repos-behind)))
    (when (> ahead 0)
      (insert "   "
              (workbench-repos--icon 'nerd-icons-codicon "nf-cod-arrow_up" 'workbench-repos-dim)
              " " (propertize (format "%d ahead" ahead) 'face 'workbench-repos-dim)))
    (when (> stashed 0)
      (insert "   "
              (workbench-repos--icon 'nerd-icons-octicon "nf-oct-archive" 'workbench-repos-dim)
              " " (propertize (format "%d stashed" stashed) 'face 'workbench-repos-dim)))
    (insert "\n\n")))

(defun workbench-repos--render-toolbar ()
  "Render the filter/sort toolbar."
  (insert "  "
          (workbench-repos--icon 'nerd-icons-mdicon "nf-md-filter" 'shadow) " "
          (propertize (capitalize (symbol-name workbench-repos--current-filter))
                      'face 'font-lock-keyword-face)
          "    "
          (workbench-repos--icon 'nerd-icons-mdicon "nf-md-sort" 'shadow) " "
          (propertize (capitalize (symbol-name workbench-repos--current-sort))
                      'face 'font-lock-keyword-face))
  (when (not (string-empty-p workbench-repos--current-search))
    (insert "    "
            (workbench-repos--icon 'nerd-icons-mdicon "nf-md-magnify" 'shadow) " "
            (propertize workbench-repos--current-search
                        'face 'font-lock-keyword-face)))
  (insert "\n")
  (workbench-repos--separator))

(defun workbench-repos--render-table (repos)
  "Render REPOS as a vtable."
  (require 'vtable)
  (make-vtable
   :use-header-line nil
   :face 'default
   :separator-width 2
   :objects repos
   :actions '("RET" workbench-repos--action-open
              "g" workbench-repos--action-magit)
   :columns
   (list
    (list :name ""
          :width 3
          :getter (lambda (repo _table)
                    (plist-get repo :state))
          :formatter (lambda (state)
                       (let ((face (if (eq state 'clean)
                                       'workbench-repos-clean
                                     'workbench-repos-dirty)))
                         (propertize "●" 'face face))))
    (list :name "Repository"
          :width 24
          :getter (lambda (repo _table)
                    (plist-get repo :name))
          :formatter (lambda (name)
                       (propertize name 'face 'workbench-repos-name)))
    (list :name "Branch"
          :width 24
          :getter (lambda (repo _table)
                    (plist-get repo :branch))
          :formatter (lambda (branch)
                       (propertize branch 'face 'workbench-repos-branch)))
    (list :name "Status"
          :width 12
          :getter (lambda (repo _table)
                    (let ((state (plist-get repo :state))
                          (dirty (plist-get repo :dirty)))
                      (if (eq state 'clean) "✓ clean" (format "%d changed" dirty))))
          :formatter (lambda (status)
                       (if (string-prefix-p "✓" status)
                           (propertize status 'face 'workbench-repos-clean)
                         (propertize status 'face 'workbench-repos-dirty))))
    (list :name "Sync"
          :width 10
          :getter (lambda (repo _table)
                    (let ((ahead (plist-get repo :ahead))
                          (behind (plist-get repo :behind))
                          (stash (or (plist-get repo :stash) 0)))
                      (concat
                       (if (> ahead 0) (format "↑%d " ahead) "")
                       (if (> behind 0) (format "↓%d " behind) "")
                       (if (> stash 0) (format "⚑%d" stash) ""))))
          :formatter (lambda (sync)
                       (if (string-empty-p sync)
                           ""
                         (propertize sync 'face
                                     (if (string-match-p "↓" sync)
                                         'workbench-repos-behind
                                       'workbench-repos-dim)))))
    (list :name "Last Commit"
          :width 12
          :getter (lambda (repo _table)
                    (or (plist-get repo :last-commit) ""))
          :formatter (lambda (time)
                       (propertize time 'face 'workbench-repos-dim))))))

(defun workbench-repos--action-open (repo)
  "Open REPO as a project workspace."
  (workbench/open-project-workspace (plist-get repo :path)))

(defun workbench-repos--action-magit (repo)
  "Open magit for REPO."
  (let ((default-directory (plist-get repo :path)))
    (workbench/toggle-popup-magit)))

(defun workbench-repos--render-footer ()
  "Render the keybinding footer."
  (workbench-repos--separator)
  (insert "\n  "
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

;; Disable evil-snipe in repos-mode — snipe intercepts s/f/S/F which we
;; use for sort/filter. Without this, pressing s runs evil-snipe-s instead
;; of workbench-repos-cycle-sort.
(add-hook 'workbench-repos-mode-hook
          (lambda ()
            (when (bound-and-true-p evil-snipe-local-mode)
              (evil-snipe-local-mode -1))
            (when (bound-and-true-p evil-snipe-override-local-mode)
              (evil-snipe-override-local-mode -1))
            ;; Belt and braces: force our bindings into the state-local map
            ;; in case snipe re-enables via a hook.
            (when (fboundp 'evil-local-set-key)
              (evil-local-set-key 'normal "s" #'workbench-repos-cycle-sort)
              (evil-local-set-key 'normal "f" #'workbench-repos-cycle-filter))))

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
  (or (when (fboundp 'vtable-current-object)
        (when-let ((obj (vtable-current-object)))
          (plist-get obj :path)))
      (get-text-property (line-beginning-position) 'workbench-repos-path)))

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
  "Open the repos dashboard in its own workspace."
  (interactive)
  (+workspace-switch "repos" t)
  (let ((buf (get-buffer workbench-repos--buffer-name)))
    (if (and buf (buffer-live-p buf) workbench-repos--statuses)
        (switch-to-buffer buf)
      (workbench-repos-refresh)
      (switch-to-buffer (get-buffer workbench-repos--buffer-name))))
  (delete-other-windows))

(provide 'workbench-repos)
;;; repos.el ends here
