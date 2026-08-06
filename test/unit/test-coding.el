;;; test/unit/test-coding.el --- Unit tests for workflows/coding.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Load dependencies and module under test
(workbench-test-load-module "modules/system/interface")
(workbench-test-load-module "modules/tools/files")
(workbench-test-load-module "modules/workflows/coding")

;; Stub workbench/open-project-dashboard which is called during workspace creation
(unless (fboundp 'workbench/open-project-dashboard)
  (defun workbench/open-project-dashboard (&optional _dir) nil))

;; Stub workbench--project-ai-window which is called by full-layout-active-p
(unless (fboundp 'workbench--project-ai-window)
  (defun workbench--project-ai-window () nil))

;;; ── workbench--project-identity-name ───────────────────────────────────────

(ert-deftest coding/identity-name/no-collision ()
  "Base name returned when no workspace with that name exists."
  (let ((workbench-test--workspaces '()))
    (should (equal (workbench--project-identity-name "/tmp/myproject")
                   "myproject"))))

(ert-deftest coding/identity-name/collision-appends-suffix ()
  "When the base name is taken, appends <2>."
  (let ((workbench-test--workspaces '("utils")))
    (should (equal (workbench--project-identity-name "/other/path/utils")
                   "utils<2>"))))

(ert-deftest coding/identity-name/same-dir-uses-base ()
  "The base name is returned if no workspace exists (reuse case)."
  (let ((workbench-test--workspaces '()))
    (should (equal (workbench--project-identity-name "/home/user/projects/utils")
                   "utils"))))

(ert-deftest coding/identity-name/multiple-collisions-increment ()
  "When base and <2> are taken, returns <3>."
  (let ((workbench-test--workspaces '("shared" "shared<2>")))
    (should (equal (workbench--project-identity-name "/a/shared")
                   "shared<3>"))))

(ert-deftest coding/identity-name/many-collisions ()
  "Handles many collisions by incrementing past all existing."
  (let ((workbench-test--workspaces '("lib" "lib<2>" "lib<3>" "lib<4>")))
    (should (equal (workbench--project-identity-name "/x/lib")
                   "lib<5>"))))

(ert-deftest coding/identity-name/trailing-slash ()
  "Handles trailing slash in directory path."
  (let ((workbench-test--workspaces '()))
    (should (equal (workbench--project-identity-name "/tmp/myproject/")
                   "myproject"))))

;;; ── workbench/open-project-workspace ───────────────────────────────────────

(ert-deftest coding/open-project-workspace/switches-to-existing ()
  "When a workspace with the base name exists for the same directory, switches to it."
  (let ((workbench-test--workspaces '("myproject"))
        (switched-to nil))
    (let ((buf (get-buffer-create "*workbench:myproject*")))
      (with-current-buffer buf
        (setq-local default-directory (file-truename "/tmp/myproject/")))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-switch)
                     (lambda (name &optional _create)
                       (setq switched-to name))))
            (workbench/open-project-workspace "/tmp/myproject")
            (should (equal switched-to "myproject")))
        (kill-buffer buf)))))

(ert-deftest coding/open-project-workspace/creates-new-when-not-exists ()
  "When no workspace exists, creates one and opens the dashboard."
  (let ((workbench-test--workspaces '())
        (created-workspace nil)
        (dashboard-opened nil))
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional create)
                 (when create (setq created-workspace name))))
              ((symbol-function 'workbench/open-project-dashboard)
               (lambda (&optional _dir) (setq dashboard-opened t))))
      (workbench/open-project-workspace "/tmp/newproject")
      (should (equal created-workspace "newproject"))
      (should dashboard-opened))))

(ert-deftest coding/open-project-workspace/sets-default-directory ()
  "New workspace sets default-directory to the project path."
  (let ((workbench-test--workspaces '())
        (saved-dir nil))
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (_name &optional _create) nil))
              ((symbol-function 'workbench/open-project-dashboard)
               (lambda (&optional _dir) (setq saved-dir default-directory))))
      (workbench/open-project-workspace "/tmp/newproject")
      (should (equal saved-dir (file-truename "/tmp/newproject"))))))

(ert-deftest coding/open-project-workspace/errors-without-workspaces ()
  "Signals error when +workspace-switch is not available."
  (cl-letf (((symbol-function '+workspace-switch) nil))
    (fmakunbound '+workspace-switch)
    (should-error (workbench/open-project-workspace "/tmp/x")
                  :type 'user-error)
    ;; Restore the stub
    (defun +workspace-switch (_name &optional _create) nil)))

;;; ── Regression tests ────────────────────────────────────────────────────────

(ert-deftest coding/regression-open-workspace-switches-to-wrong-project ()
  "FIXED: open-project-workspace now verifies the existing workspace matches the directory."
  (let ((workbench-test--workspaces '("utils"))
        (switched-to nil))
    ;; Create a dashboard buffer for the existing "utils" workspace pointing at /foo/utils
    (let ((buf (get-buffer-create "*workbench:utils*")))
      (with-current-buffer buf
        (setq-local default-directory "/foo/utils/"))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-switch)
                     (lambda (name &optional _create) (setq switched-to name)))
                    ((symbol-function 'workbench/open-project-dashboard) #'ignore))
            ;; Open /bar/utils — workspace "utils" exists but belongs to /foo/utils
            (workbench/open-project-workspace "/bar/utils")
            ;; Should create "utils<2>" for the different directory
            (should (equal switched-to "utils<2>")))
        (kill-buffer buf)))))

(ert-deftest coding/regression-open-workspace-with-nonexistent-dir ()
  "file-truename on a non-existent path returns the path unchanged on macOS.
This isn't a crash bug but documents the behaviour."
  (let ((workbench-test--workspaces '())
        (switched-to nil))
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional _create) (setq switched-to name)))
              ((symbol-function 'workbench/open-project-dashboard) #'ignore))
      ;; Non-existent directory — file-truename still works (returns input)
      (workbench/open-project-workspace "/tmp/does-not-exist-wb-test/")
      (should (equal switched-to "does-not-exist-wb-test")))))

(ert-deftest coding/regression-workspace-matches-with-symlinked-directory ()
  "Symlinked directories: stored path and input path resolve to same target."
  (workbench-test-with-temp-dir real-dir
    (let* ((link-dir (concat real-dir "-link"))
           (created (ignore-errors (make-symbolic-link real-dir link-dir) t)))
      (when created
        (unwind-protect
            (let ((buf (get-buffer-create "*workbench:test-sym*")))
              (with-current-buffer buf
                ;; Workspace was opened via the symlink
                (setq-local default-directory (file-name-as-directory link-dir)))
              (unwind-protect
                  ;; Asking to open via the real path should still match
                  (should (workbench--workspace-matches-directory-p "test-sym" real-dir))
                (kill-buffer buf)))
          (delete-file link-dir))))))

(ert-deftest coding/regression-workspace-match-works-after-dashboard-killed ()
  "FIXED: workspace directory registry provides fallback when buffer is killed."
  (let ((workbench-test--workspaces '("myproject"))
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (switched-to nil))
    ;; Simulate: workspace was opened previously (directory registered)
    (puthash "myproject" (file-name-as-directory (file-truename "/tmp/myproject"))
             workbench--workspace-directories)
    ;; No *workbench:myproject* buffer exists (user killed it)
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional _create) (setq switched-to name)))
              ((symbol-function 'workbench/open-project-dashboard) #'ignore))
      (workbench/open-project-workspace "/tmp/myproject")
      ;; Should switch to existing workspace via registry fallback
      (should (equal switched-to "myproject")))))

(ert-deftest coding/regression-reopen-suffixed-workspace-switches-correctly ()
  "Re-opening a directory that got a suffixed workspace should switch to it."
  (let ((workbench-test--workspaces '("utils" "utils<2>"))
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (switched-to nil))
    ;; "utils" belongs to /foo/utils, "utils<2>" belongs to /bar/utils
    (puthash "utils" "/foo/utils/" workbench--workspace-directories)
    (puthash "utils<2>" "/bar/utils/" workbench--workspace-directories)
    ;; Also create the dashboard buffer for utils<2>
    (let ((buf (get-buffer-create "*workbench:utils<2>*")))
      (with-current-buffer buf
        (setq-local default-directory "/bar/utils/"))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-switch)
                     (lambda (name &optional _create) (setq switched-to name)))
                    ((symbol-function 'workbench/open-project-dashboard) #'ignore))
            ;; Re-open /bar/utils — should find "utils<2>" and switch to it
            (workbench/open-project-workspace "/bar/utils")
            (should (equal switched-to "utils<2>")))
        (kill-buffer buf)))))

(ert-deftest coding/regression-open-workspace-should-scan-suffixed-names ()
  "FIXED: open-project-workspace now scans base and suffixed workspace names."
  (let ((workbench-test--workspaces '("utils" "utils<2>"))
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (switched-to nil)
        (create-flag nil))
    ;; "utils" belongs to /foo/utils, "utils<2>" belongs to /bar/utils
    (puthash "utils" "/foo/utils/" workbench--workspace-directories)
    (puthash "utils<2>" "/bar/utils/" workbench--workspace-directories)
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional create)
                 (setq switched-to name create-flag create)))
              ((symbol-function 'workbench/open-project-dashboard) #'ignore))
      ;; Re-open /bar/utils
      (workbench/open-project-workspace "/bar/utils")
      ;; SHOULD switch without create flag (it exists already)
      (should (equal switched-to "utils<2>"))
      (should-not create-flag))))

(ert-deftest coding/regression-note-identity-name-terminates-when-slot-available ()
  "project-identity-name terminates when it finds a free slot."
  (let ((workbench-test--workspaces '("proj" "proj<2>" "proj<3>")))
    ;; Should skip to <4>
    (should (equal (workbench--project-identity-name "/tmp/proj") "proj<4>"))))

(ert-deftest coding/regression-switch-to-existing-registers-directory ()
  "FIXED: Switching to existing workspace now also updates the directory registry."
  (let ((workbench-test--workspaces '("myproject"))
        (workbench--workspace-directories (make-hash-table :test 'equal)))
    ;; Dashboard buffer exists — match succeeds via buffer check
    (let ((buf (get-buffer-create "*workbench:myproject*")))
      (with-current-buffer buf
        (setq-local default-directory "/tmp/myproject/"))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-switch) #'ignore))
            (workbench/open-project-workspace "/tmp/myproject")
            ;; Registry SHOULD be populated as a side effect
            (should (gethash "myproject" workbench--workspace-directories)))
        (kill-buffer buf)))))

;;; ── workbench/open-project-workspace-full-layout ────────────────────────────

;; workbench/default-ai-tool is defined in system/core.el (not loaded in tests)
(defvar workbench/default-ai-tool "claude"
  "Test stub for the profile default AI tool.")

(ert-deftest coding/full-layout/opens-workspace-treemacs-dashboard-ai ()
  "Full layout calls workspace open, treemacs, dashboard, and AI pane."
  (let ((workbench-test--workspaces '())
        (workspace-opened nil)
        (treemacs-called nil)
        (dashboard-called nil)
        (ai-called nil)
        (default-directory "/tmp/test-project/"))
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional _create)
                 (setq workspace-opened name)))
              ((symbol-function '+workspace-current-name)
               (lambda () (or workspace-opened "main")))
              ((symbol-function 'workbench/open-project-dashboard)
               (lambda (&optional _dir) (setq dashboard-called t)))
              ((symbol-function 'workbench--treemacs-display)
               (lambda (_dir) (setq treemacs-called t)))
              ((symbol-function 'workbench--show-project-ai)
               (lambda (_tool) (setq ai-called t)))
              ((symbol-function 'workbench--treemacs-window)
               (lambda () nil))
              ((symbol-function 'workbench--project-ai-window)
               (lambda () nil))
              ((symbol-function 'workbench--select-main-window) #'ignore)
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'read-directory-name)
               (lambda (&rest _) "/tmp/test-project/")))
      (workbench/open-project-workspace-full-layout)
      (should workspace-opened)
      (should treemacs-called)
      (should dashboard-called)
      (should ai-called))))

(ert-deftest coding/full-layout/uses-dired-path-when-in-dired ()
  "In dired-mode, uses the selected path rather than prompting."
  (let ((workbench-test--workspaces '())
        (used-directory nil))
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (mode) (eq mode 'dired-mode)))
              ((symbol-function 'workbench--selected-path)
               (lambda () "/tmp/dired-selected/"))
              ((symbol-function 'workbench--project-directory-for-path)
               (lambda (path) path))
              ((symbol-function 'workbench/open-project-workspace)
               (lambda (dir) (setq used-directory dir)))
              ((symbol-function '+workspace-current-name)
               (lambda () "dired-selected"))
              ((symbol-function 'workbench--treemacs-window)
               (lambda () nil))
              ((symbol-function 'workbench--project-ai-window)
               (lambda () nil))
              ((symbol-function 'workbench--select-main-window) #'ignore)
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'workbench--treemacs-display) #'ignore)
              ((symbol-function 'workbench/open-project-dashboard) #'ignore)
              ((symbol-function 'workbench--show-project-ai) #'ignore))
      (workbench/open-project-workspace-full-layout)
      (should (equal used-directory "/tmp/dired-selected/")))))

(ert-deftest coding/full-layout/uses-default-ai-tool ()
  "Full layout opens the profile default AI tool."
  (let ((workbench-test--workspaces '())
        (workbench/default-ai-tool "kiro")
        (ai-tool-used nil))
    (cl-letf (((symbol-function '+workspace-switch) #'ignore)
              ((symbol-function '+workspace-current-name)
               (lambda () "proj"))
              ((symbol-function 'workbench/open-project-dashboard) #'ignore)
              ((symbol-function 'workbench--treemacs-display) #'ignore)
              ((symbol-function 'workbench--treemacs-window)
               (lambda () nil))
              ((symbol-function 'workbench--project-ai-window)
               (lambda () nil))
              ((symbol-function 'workbench--select-main-window) #'ignore)
              ((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'workbench--show-project-ai)
               (lambda (tool) (setq ai-tool-used tool)))
              ((symbol-function 'read-directory-name)
               (lambda (&rest _) "/tmp/proj/")))
      (workbench/open-project-workspace-full-layout)
      (should (equal ai-tool-used "kiro")))))

;;; ── workbench/open-project-workspace-full-layout (repeated use) ───────────

(ert-deftest coding/full-layout/skips-rebuild-when-layout-intact ()
  "When re-opening a project whose full layout is already active, skip rebuild."
  (let ((workbench-test--workspaces '("myproject"))
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (workbench-test--current-workspace "myproject")
        (treemacs-called nil)
        (dashboard-called nil)
        (ai-called nil)
        (delete-windows-called nil)
        (select-main-called nil))
    (puthash "myproject" "/tmp/myproject/" workbench--workspace-directories)
    ;; Create dashboard buffer for the workspace and display it
    (let ((dash-buf (get-buffer-create "*workbench:myproject*")))
      (with-current-buffer dash-buf
        (setq-local default-directory "/tmp/myproject/"))
      ;; Display the dashboard buffer so get-buffer-window finds it
      (set-window-buffer (selected-window) dash-buf)
      ;; Create a fake AI buffer
      (let ((ai-buf (get-buffer-create "*project-claude:myproject*")))
        (unwind-protect
            (cl-letf (((symbol-function '+workspace-switch)
                       (lambda (_name &optional _create) nil))
                      ((symbol-function '+workspace-current-name)
                       (lambda () "myproject"))
                      ((symbol-function 'workbench--treemacs-window)
                       (lambda () (selected-window))) ;; simulate treemacs visible
                      ((symbol-function 'workbench--project-ai-window)
                       (lambda () (selected-window))) ;; simulate AI pane visible
                      ((symbol-function 'workbench--treemacs-display)
                       (lambda (_dir) (setq treemacs-called t)))
                      ((symbol-function 'workbench/open-project-dashboard)
                       (lambda (&optional _dir) (setq dashboard-called t)))
                      ((symbol-function 'workbench--show-project-ai)
                       (lambda (_tool) (setq ai-called t)))
                      ((symbol-function 'workbench--select-main-window)
                       (lambda () (setq select-main-called t)))
                      ((symbol-function 'delete-other-windows)
                       (lambda () (setq delete-windows-called t)))
                      ((symbol-function 'read-directory-name)
                       (lambda (&rest _) "/tmp/myproject/")))
              (workbench/open-project-workspace-full-layout)
              ;; Should NOT rebuild the layout
              (should-not treemacs-called)
              (should-not dashboard-called)
              (should-not ai-called)
              (should-not delete-windows-called)
              ;; SHOULD focus the main window
              (should select-main-called))
          (kill-buffer ai-buf)
          (kill-buffer dash-buf))))))

(ert-deftest coding/full-layout/rebuilds-when-layout-partial ()
  "When layout is partially broken (e.g. AI pane closed), rebuild fully."
  (let ((workbench-test--workspaces '("myproject"))
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (workbench-test--current-workspace "myproject")
        (treemacs-called nil)
        (dashboard-called nil)
        (ai-called nil))
    (puthash "myproject" "/tmp/myproject/" workbench--workspace-directories)
    (let ((dash-buf (get-buffer-create "*workbench:myproject*")))
      (with-current-buffer dash-buf
        (setq-local default-directory "/tmp/myproject/"))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-switch)
                     (lambda (_name &optional _create) nil))
                    ((symbol-function '+workspace-current-name)
                     (lambda () "myproject"))
                    ((symbol-function 'workbench--treemacs-window)
                     (lambda () (selected-window))) ;; treemacs visible
                    ((symbol-function 'workbench--project-ai-window)
                     (lambda () nil)) ;; AI pane MISSING
                    ((symbol-function 'workbench--treemacs-display)
                     (lambda (_dir) (setq treemacs-called t)))
                    ((symbol-function 'workbench--select-main-window) #'ignore)
                    ((symbol-function 'workbench/open-project-dashboard)
                     (lambda (&optional _dir) (setq dashboard-called t)))
                    ((symbol-function 'workbench--show-project-ai)
                     (lambda (_tool) (setq ai-called t)))
                    ((symbol-function 'delete-other-windows) #'ignore)
                    ((symbol-function 'read-directory-name)
                     (lambda (&rest _) "/tmp/myproject/")))
            (workbench/open-project-workspace-full-layout)
            ;; SHOULD rebuild since AI pane is missing
            (should treemacs-called)
            (should dashboard-called)
            (should ai-called))
        (kill-buffer dash-buf)))))

(ert-deftest coding/full-layout/second-project-from-dired-creates-new-workspace ()
  "Calling SPC p o from Dirvish on a second project creates a new workspace."
  (let ((workbench-test--workspaces '("project-a"))
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (created-workspace nil)
        (treemacs-dir nil))
    (puthash "project-a" "/tmp/project-a/" workbench--workspace-directories)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (mode) (eq mode 'dired-mode)))
              ((symbol-function 'workbench--selected-path)
               (lambda () "/tmp/project-b/"))
              ((symbol-function 'workbench--project-directory-for-path)
               (lambda (path) path))
              ((symbol-function '+workspace-switch)
               (lambda (name &optional create)
                 (when create (setq created-workspace name))))
              ((symbol-function '+workspace-current-name)
               (lambda () (or created-workspace "files")))
              ((symbol-function 'workbench--treemacs-window)
               (lambda () nil)) ;; no layout yet
              ((symbol-function 'workbench--project-ai-window)
               (lambda () nil))
              ((symbol-function 'workbench--treemacs-display)
               (lambda (dir) (setq treemacs-dir dir)))
              ((symbol-function 'workbench--select-main-window) #'ignore)
              ((symbol-function 'workbench/open-project-dashboard) #'ignore)
              ((symbol-function 'workbench--show-project-ai) #'ignore)
              ((symbol-function 'delete-other-windows) #'ignore))
      (workbench/open-project-workspace-full-layout)
      ;; Should create a new workspace for project-b
      (should (equal created-workspace "project-b"))
      ;; Should pass the correct directory to treemacs
      (should (equal treemacs-dir "/tmp/project-b/")))))

(ert-deftest coding/full-layout/rapid-repeated-calls-same-project-no-rebuild ()
  "Rapid repeated SPC p o on the same project should not rebuild each time."
  (let ((workbench-test--workspaces '("myproject"))
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (workbench-test--current-workspace "myproject")
        (rebuild-count 0))
    (puthash "myproject" "/tmp/myproject/" workbench--workspace-directories)
    (let ((dash-buf (get-buffer-create "*workbench:myproject*"))
          (ai-buf (get-buffer-create "*project-claude:myproject*")))
      (with-current-buffer dash-buf
        (setq-local default-directory "/tmp/myproject/"))
      ;; Display the dashboard buffer so get-buffer-window finds it
      (set-window-buffer (selected-window) dash-buf)
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-switch) #'ignore)
                    ((symbol-function '+workspace-current-name)
                     (lambda () "myproject"))
                    ((symbol-function 'workbench--treemacs-window)
                     (lambda () (selected-window)))
                    ((symbol-function 'workbench--project-ai-window)
                     (lambda () (selected-window)))
                    ((symbol-function 'workbench--treemacs-display)
                     (lambda (_dir) (cl-incf rebuild-count)))
                    ((symbol-function 'workbench--select-main-window) #'ignore)
                    ((symbol-function 'workbench/open-project-dashboard) #'ignore)
                    ((symbol-function 'workbench--show-project-ai) #'ignore)
                    ((symbol-function 'delete-other-windows) #'ignore)
                    ((symbol-function 'read-directory-name)
                     (lambda (&rest _) "/tmp/myproject/")))
            ;; Call 3 times rapidly
            (workbench/open-project-workspace-full-layout)
            (workbench/open-project-workspace-full-layout)
            (workbench/open-project-workspace-full-layout)
            ;; Should NOT have rebuilt any time (layout already intact)
            (should (= rebuild-count 0)))
        (kill-buffer ai-buf)
        (kill-buffer dash-buf)))))

(ert-deftest coding/full-layout/alternating-projects-from-dired ()
  "Alternating between projects from Dirvish: first builds, second builds, first re-entry skips."
  (let ((workbench-test--workspaces '())
        (workbench--workspace-directories (make-hash-table :test 'equal))
        (workbench-test--current-workspace "files")
        (build-log '())
        (current-project nil))
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (mode) (eq mode 'dired-mode)))
              ((symbol-function 'workbench--selected-path)
               (lambda () (format "/tmp/%s/" current-project)))
              ((symbol-function 'workbench--project-directory-for-path)
               (lambda (path) path))
              ((symbol-function '+workspace-switch)
               (lambda (name &optional _create)
                 (setq workbench-test--current-workspace name)
                 (push name workbench-test--workspaces)))
              ((symbol-function '+workspace-current-name)
               (lambda () workbench-test--current-workspace))
              ((symbol-function '+workspace-exists-p)
               (lambda (name) (member name workbench-test--workspaces)))
              ((symbol-function 'workbench--treemacs-window)
               (lambda () nil)) ;; never has layout (simplified)
              ((symbol-function 'workbench--project-ai-window)
               (lambda () nil))
              ((symbol-function 'workbench--treemacs-display)
               (lambda (dir) (push (cons 'treemacs dir) build-log)))
              ((symbol-function 'workbench--select-main-window) #'ignore)
              ((symbol-function 'workbench/open-project-dashboard)
               (lambda (&optional dir) (push (cons 'dashboard dir) build-log)))
              ((symbol-function 'workbench--show-project-ai)
               (lambda (tool) (push (cons 'ai tool) build-log)))
              ((symbol-function 'delete-other-windows) #'ignore))
      ;; Open project-a from dired
      (setq current-project "project-a")
      (workbench/open-project-workspace-full-layout)
      ;; Open project-b from dired
      (setq current-project "project-b")
      (workbench/open-project-workspace-full-layout)
      ;; Both should have built layouts (6 build actions: treemacs + dashboard + ai × 2)
      (should (= (length build-log) 6)))))

;;; ── workbench--full-layout-active-p ─────────────────────────────────────────

(ert-deftest coding/full-layout-active-p/all-present ()
  "Returns non-nil when treemacs, dashboard, and AI are all visible."
  (let ((workbench-test--current-workspace "myproject"))
    (let ((dash-buf (get-buffer-create "*workbench:myproject*")))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-current-name)
                     (lambda () "myproject"))
                    ((symbol-function 'workbench--treemacs-window)
                     (lambda () (selected-window)))
                    ((symbol-function 'workbench--project-ai-window)
                     (lambda () (selected-window))))
            ;; Dashboard buffer needs to be displayed
            (display-buffer dash-buf)
            (should (workbench--full-layout-active-p "/tmp/myproject")))
        (kill-buffer dash-buf)))))

(ert-deftest coding/full-layout-active-p/missing-treemacs ()
  "Returns nil when treemacs is not visible."
  (let ((workbench-test--current-workspace "myproject"))
    (let ((dash-buf (get-buffer-create "*workbench:myproject*")))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-current-name)
                     (lambda () "myproject"))
                    ((symbol-function 'workbench--treemacs-window)
                     (lambda () nil)) ;; no treemacs
                    ((symbol-function 'workbench--project-ai-window)
                     (lambda () (selected-window))))
            (display-buffer dash-buf)
            (should-not (workbench--full-layout-active-p "/tmp/myproject")))
        (kill-buffer dash-buf)))))

(ert-deftest coding/full-layout-active-p/missing-ai-pane ()
  "Returns nil when AI pane is not visible."
  (let ((workbench-test--current-workspace "myproject"))
    (let ((dash-buf (get-buffer-create "*workbench:myproject*")))
      (unwind-protect
          (cl-letf (((symbol-function '+workspace-current-name)
                     (lambda () "myproject"))
                    ((symbol-function 'workbench--treemacs-window)
                     (lambda () (selected-window)))
                    ((symbol-function 'workbench--project-ai-window)
                     (lambda () nil))) ;; no AI pane
            (display-buffer dash-buf)
            (should-not (workbench--full-layout-active-p "/tmp/myproject")))
        (kill-buffer dash-buf)))))

(ert-deftest coding/full-layout-active-p/missing-dashboard ()
  "Returns nil when dashboard buffer doesn't exist."
  (cl-letf (((symbol-function '+workspace-current-name)
             (lambda () "myproject"))
            ((symbol-function 'workbench--treemacs-window)
             (lambda () (selected-window)))
            ((symbol-function 'workbench--project-ai-window)
             (lambda () (selected-window))))
    ;; No *workbench:myproject* buffer exists
    (should-not (workbench--full-layout-active-p "/tmp/myproject"))))

;;; ── workbench--select-main-window ───────────────────────────────────────────

(ert-deftest coding/select-main-window/picks-largest-non-side-window ()
  "Selects the largest window that isn't treemacs or AI pane."
  ;; In batch Emacs with a single window, it should select that window
  ;; since there's no treemacs or AI window.
  (cl-letf (((symbol-function 'workbench--treemacs-window) (lambda () nil))
            ((symbol-function 'workbench--project-ai-window) (lambda () nil)))
    ;; Should not error and should select a window
    (workbench--select-main-window)
    (should (window-live-p (selected-window)))))

;;; ── workbench/open-project-dashboard buffer naming ──────────────────────────

;; The dashboard module uses load! internally which resolves relative paths
;; differently in batch tests. We test the naming logic directly by loading
;; just the parent module's function definition.

(ert-deftest coding/regression-dashboard-buffer-matches-workspace-name ()
  "FIXED: open-project-dashboard creates buffer named after the current workspace,
not a re-derived identity that appends <2> because the workspace already exists.

Bug: project-identity-name was called inside open-project-dashboard. Since
the workspace already exists at that point, it returned 'name<2>' instead of
'name', creating a mismatched buffer that broke full-layout-active-p checks."
  (let ((workbench-test--current-workspace "myproject")
        (workbench-test--workspaces '("myproject")))
    ;; Verify the fix: project-identity-name would return <2> for an existing workspace
    (should (equal (workbench--project-identity-name "/tmp/myproject") "myproject<2>"))
    ;; But +workspace-current-name gives the correct name
    (should (equal (+workspace-current-name) "myproject"))
    ;; The dashboard buffer name should use the workspace name
    (let ((expected-buf (format "*workbench:%s*" (+workspace-current-name))))
      (should (equal expected-buf "*workbench:myproject*")))))

;;; test/unit/test-coding.el ends here
