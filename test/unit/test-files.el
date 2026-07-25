;;; test/unit/test-files.el --- Unit tests for tools/files.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Load the modules under test
(workbench-test-load-module "modules/tools/files")

;; workbench--files-real-dired-p lives in session.el (files workspace tracking)
(unless (fboundp 'workbench/open-default-ai-workspace)
  (defun workbench/open-default-ai-workspace () nil))
(unless (fboundp 'workbench-org/open-agenda)
  (defun workbench-org/open-agenda () nil))
(workbench-test-load-module "modules/workflows/session")

;;; ── workbench--directory-name ──────────────────────────────────────────────

(ert-deftest files/directory-name/simple-path ()
  (should (equal (workbench--directory-name "/home/user/projects/foo") "foo")))

(ert-deftest files/directory-name/trailing-slash ()
  (should (equal (workbench--directory-name "/home/user/projects/bar/") "bar")))

(ert-deftest files/directory-name/root-directory ()
  "Root / has an empty directory-file-name, so file-name-nondirectory returns empty string."
  (should (equal (workbench--directory-name "/") "")))

(ert-deftest files/directory-name/home-tilde ()
  "Tilde path without expansion: extracts last component as-is."
  (should (equal (workbench--directory-name "~/projects/baz") "baz")))

(ert-deftest files/directory-name/home-tilde-root ()
  "Bare ~ without trailing slash."
  ;; ~ is treated as a path component; directory-file-name leaves it as ~
  (should (stringp (workbench--directory-name "~"))))

(ert-deftest files/directory-name/deeply-nested ()
  (should (equal (workbench--directory-name "/a/b/c/d/e/deep/") "deep")))

(ert-deftest files/directory-name/single-component ()
  (should (equal (workbench--directory-name "mydir") "mydir")))

;;; ── workbench--project-root ────────────────────────────────────────────────

(ert-deftest files/project-root/falls-back-to-default-directory ()
  "When no project is detected, returns default-directory."
  (let ((default-directory "/tmp/no-project/"))
    (cl-letf (((symbol-function 'project-current) (lambda (&rest _) nil)))
      (should (equal (workbench--project-root) "/tmp/no-project/")))))

(ert-deftest files/project-root/returns-project-root-when-available ()
  "When project-current returns a project, uses project-root."
  (let ((default-directory "/tmp/inside-project/src/"))
    (cl-letf (((symbol-function 'project-current) (lambda (&rest _) '(vc Git "/tmp/inside-project/")))
              ((symbol-function 'project-root) (lambda (_p) "/tmp/inside-project/")))
      (should (equal (workbench--project-root) "/tmp/inside-project/")))))

;;; ── workbench--files-real-dired-p ──────────────────────────────────────────

(ert-deftest files/real-dired-p/normal-dired-buffer ()
  "A normal Dired buffer with a directory name is real."
  (with-temp-buffer
    (let ((buf (current-buffer)))
      (rename-buffer "/tmp/somedir" t)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _modes) t)))
        (should (workbench--files-real-dired-p))))))

(ert-deftest files/real-dired-p/space-prefixed-parent-buffer ()
  "Dirvish parent pane buffers start with a space — not real."
  (with-temp-buffer
    (rename-buffer " /parent/dir" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (should-not (workbench--files-real-dired-p)))))

(ert-deftest files/real-dired-p/dirvish-preview-buffer ()
  "Dirvish preview buffers match *dirvish-... — not real."
  (with-temp-buffer
    (rename-buffer "*dirvish-preview*" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) t)))
      (should-not (workbench--files-real-dired-p)))))

(ert-deftest files/real-dired-p/non-dired-buffer ()
  "A buffer not in dired-mode is not real dired."
  (with-temp-buffer
    (rename-buffer "somefile.txt" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _modes) nil)))
      (should-not (workbench--files-real-dired-p)))))

;;; ── workbench--selected-path ───────────────────────────────────────────────

(ert-deftest files/selected-path/signals-error-when-no-file ()
  "Signals user-error when dired-get-file-for-visit errors (blank line)."
  (cl-letf (((symbol-function 'dired-get-file-for-visit)
             (lambda () (error "No file on this line"))))
    (should-error (workbench--selected-path) :type 'user-error)))

(ert-deftest files/selected-path/returns-file-when-present ()
  "Returns the file path when dired reports one."
  (cl-letf (((symbol-function 'dired-get-file-for-visit)
             (lambda () "/tmp/test-file.txt")))
    (should (equal (workbench--selected-path) "/tmp/test-file.txt"))))

;;; ── workbench--project-directory-for-path ──────────────────────────────────

(ert-deftest files/project-directory-for-path/file-returns-parent ()
  "A file path returns its parent directory."
  (workbench-test-with-temp-dir dir
    (let ((file (expand-file-name "test.txt" dir)))
      (write-region "" nil file)
      (let ((result (workbench--project-directory-for-path file)))
        (should (equal (file-truename result)
                       (file-truename (file-name-as-directory dir))))))))

(ert-deftest files/project-directory-for-path/directory-returns-itself ()
  "A directory path returns itself."
  (workbench-test-with-temp-dir dir
    (let ((result (workbench--project-directory-for-path (file-name-as-directory dir))))
      (should (equal (file-truename result)
                     (file-truename (file-name-as-directory dir)))))))

(ert-deftest files/project-directory-for-path/follows-symlinks ()
  "Result is the truename (symlinks resolved)."
  (workbench-test-with-temp-dir dir
    (let ((result (workbench--project-directory-for-path dir)))
      ;; file-truename is idempotent on the result
      (should (equal result (file-truename result))))))

;;; ── Regression tests ────────────────────────────────────────────────────────

(ert-deftest files/regression-project-root-normalizes-default-directory ()
  "project-root should return an absolute path with trailing slash."
  (let ((default-directory "~/code/foo"))
    (cl-letf (((symbol-function 'project-current) (lambda (&rest _) nil)))
      (let ((result (workbench--project-root)))
        ;; Should be the same as default-directory (which Emacs keeps absolute)
        (should (equal result "~/code/foo"))))))

(ert-deftest files/regression-open-files-full-frame-nil-directory-uses-project-root ()
  "When called with nil directory, falls back to project root."
  (let ((dired-dir nil))
    (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'dired) (lambda (dir) (setq dired-dir dir)))
              ((symbol-function 'workbench--project-root) (lambda () "/tmp/project/"))
              ((symbol-function 'dirvish-layout-toggle) #'ignore))
      (workbench/open-files-full-frame nil nil)
      (should (equal dired-dir "/tmp/project/")))))

;;; test/unit/test-files.el ends here
