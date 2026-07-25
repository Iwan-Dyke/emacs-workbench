;;; test/unit/test-coding.el --- Unit tests for workflows/coding.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Load dependencies and module under test
(workbench-test-load-module "modules/tools/files")
(workbench-test-load-module "modules/workflows/coding")

;; Stub workbench/open-project-dashboard which is called during workspace creation
(unless (fboundp 'workbench/open-project-dashboard)
  (defun workbench/open-project-dashboard (&optional _dir) nil))

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

;;; test/unit/test-coding.el ends here
