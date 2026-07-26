;;; test/unit/test-repos-render.el --- Tests for repos rendering -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

(require 'test-helper)
(workbench-test-load-module "modules/workflows/repos-data.el")
(workbench-test-load-module "modules/workflows/repos.el")

;;; ── Buffer rendering ───────────────────────────────────────────────────────

(defvar test-repos-render--sample
  (list (list :name "emacs-workbench" :path "/Users/test/code/emacs-workbench"
              :branch "main" :state 'clean :dirty 0 :ahead 0 :behind 0
              :last-commit "2h ago" :stash 0)
        (list :name "sifft" :path "/Users/test/code/sifft"
              :branch "feature/validate" :state 'dirty :dirty 2 :ahead 1 :behind 0
              :last-commit "5m ago" :stash 1)
        (list :name "infrastructure" :path "/Users/test/code/infrastructure"
              :branch "main" :state 'clean :dirty 0 :ahead 0 :behind 3
              :last-commit "1d ago" :stash 0)))

(ert-deftest repos-render/creates-buffer ()
  "Render creates the repos buffer with correct name."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (progn
          (should (buffer-live-p buf))
          (should (equal (buffer-name buf) "*repos*")))
      (kill-buffer buf))))

(ert-deftest repos-render/shows-all-repo-names ()
  "All repo names appear in the rendered buffer."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "emacs-workbench" content))
            (should (string-match-p "sifft" content))
            (should (string-match-p "infrastructure" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/shows-branches ()
  "Branch names appear in the rendered buffer."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "main" content))
            (should (string-match-p "feature/validate" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/shows-dirty-count ()
  "Dirty file count appears for dirty repos."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "2" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/shows-behind-indicator ()
  "Behind count appears for repos behind remote."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "↓3" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/shows-ahead-indicator ()
  "Ahead count appears for repos ahead of remote."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "↑1" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/shows-stash-indicator ()
  "Stash count appears when non-zero."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "⚑1" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/header-shows-summary ()
  "Header shows total count and dirty/behind counts."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "3 repos" content))
            (should (string-match-p "1 dirty" content))
            (should (string-match-p "1 behind" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/footer-shows-keybindings ()
  "Footer shows available keybindings."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (let ((content (buffer-string)))
            (should (string-match-p "\\[r\\]" content))
            (should (string-match-p "\\[f\\]" content))
            (should (string-match-p "\\[p\\]" content))))
      (kill-buffer buf))))

(ert-deftest repos-render/empty-list-shows-message ()
  "Empty repo list shows helpful message."
  (let ((buf (workbench-repos--render '())))
    (unwind-protect
        (with-current-buffer buf
          (should (string-match-p "No repos" (buffer-string))))
      (kill-buffer buf))))

;;; ── Mode and keybindings ───────────────────────────────────────────────────

(ert-deftest repos-render/buffer-is-read-only ()
  "Repos buffer is read-only."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (should buffer-read-only))
      (kill-buffer buf))))

(ert-deftest repos-render/mode-is-set ()
  "Repos buffer uses workbench-repos-mode."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (should (eq major-mode 'workbench-repos-mode)))
      (kill-buffer buf))))

;;; ── Text properties (colour coding) ────────────────────────────────────────

(ert-deftest repos-render/clean-repos-have-success-face ()
  "Clean repos are rendered with success face."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (goto-char (point-min))
          (search-forward "emacs-workbench")
          ;; Check the status pip before the name
          (goto-char (match-beginning 0))
          (backward-char 2)
          (let ((face (get-text-property (point) 'face)))
            (should (or (eq face 'success)
                        (and (listp face) (memq 'success face))
                        ;; May be a custom face inheriting success
                        (equal face 'workbench-repos-clean)))))
      (kill-buffer buf))))

(ert-deftest repos-render/dirty-repos-have-warning-face ()
  "Dirty repos are rendered with warning face."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (goto-char (point-min))
          (search-forward "sifft")
          (goto-char (match-beginning 0))
          (backward-char 2)
          (let ((face (get-text-property (point) 'face)))
            (should (or (eq face 'warning)
                        (and (listp face) (memq 'warning face))
                        (equal face 'workbench-repos-dirty)))))
      (kill-buffer buf))))

;;; ── Path text property for navigation ──────────────────────────────────────

(ert-deftest repos-render/repo-lines-have-path-property ()
  "Each repo line has a workbench-repos-path text property for navigation."
  (let ((buf (workbench-repos--render test-repos-render--sample)))
    (unwind-protect
        (with-current-buffer buf
          (goto-char (point-min))
          (search-forward "sifft")
          (let ((path (get-text-property (match-beginning 0) 'workbench-repos-path)))
            (should (equal path "/Users/test/code/sifft"))))
      (kill-buffer buf))))

(provide 'test-repos-render)
;;; test-repos-render.el ends here
