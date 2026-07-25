;;; test/unit/test-dashboard.el --- Unit tests for project-dashboard-data.el and command-centre-svg.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Stub for workbench--directory-name which project-dashboard-data declares
(unless (fboundp 'workbench--directory-name)
  (defun workbench--directory-name (dir)
    (file-name-nondirectory (directory-file-name dir))))

;; Load modules under test
(workbench-test-load-module "modules/workflows/project-dashboard-data")
(workbench-test-load-module "modules/workflows/command-centre-svg")

;;; ── workbench--dashboard-description ───────────────────────────────────────

(ert-deftest dashboard-description/extracts-from-pyproject-toml ()
  (workbench-test-with-temp-dir dir
    (with-temp-file (expand-file-name "pyproject.toml" dir)
      (insert "[project]\nname = \"myapp\"\ndescription = \"A fast build tool\"\nversion = \"1.0\"\n"))
    (should (equal (workbench--dashboard-description dir) "A fast build tool"))))

(ert-deftest dashboard-description/extracts-from-package-json ()
  (workbench-test-with-temp-dir dir
    (with-temp-file (expand-file-name "package.json" dir)
      (insert "{\n  \"name\": \"mylib\",\n  \"description\": \"Utility library for Node\",\n  \"version\": \"2.0.0\"\n}\n"))
    (should (equal (workbench--dashboard-description dir) "Utility library for Node"))))

(ert-deftest dashboard-description/extracts-from-readme-first-non-heading ()
  (workbench-test-with-temp-dir dir
    (with-temp-file (expand-file-name "README.md" dir)
      (insert "# My Project\n\nA powerful framework for building web apps.\n\n## Installation\n"))
    (should (equal (workbench--dashboard-description dir)
                   "A powerful framework for building web apps."))))

(ert-deftest dashboard-description/prefers-pyproject-over-readme ()
  (workbench-test-with-temp-dir dir
    (with-temp-file (expand-file-name "pyproject.toml" dir)
      (insert "[project]\ndescription = \"From pyproject\"\n"))
    (with-temp-file (expand-file-name "README.md" dir)
      (insert "# Title\n\nFrom README.\n"))
    (should (equal (workbench--dashboard-description dir) "From pyproject"))))

(ert-deftest dashboard-description/returns-nil-when-no-sources ()
  (workbench-test-with-temp-dir dir
    (should-not (workbench--dashboard-description dir))))

;;; ── workbench--dashboard-languages ─────────────────────────────────────────

(ert-deftest dashboard-languages/counts-extensions-sorted-by-frequency ()
  (workbench-test-with-temp-dir dir
    ;; Create a git repo with tracked files
    (let ((default-directory dir))
      (call-process "git" nil nil nil "init" "-q")
      (call-process "git" nil nil nil "config" "user.email" "test@test.com")
      (call-process "git" nil nil nil "config" "user.name" "Test")
      ;; Create files with different extensions
      (dolist (f '("a.py" "b.py" "c.py" "d.js" "e.js" "f.el"))
        (with-temp-file (expand-file-name f dir)
          (insert "content")))
      (call-process "git" nil nil nil "add" ".")
      (call-process "git" nil nil nil "commit" "-m" "init" "-q"))
    (let ((result (workbench--dashboard-languages dir)))
      (should result)
      ;; py should be first (3 files), js second (2), el third (1)
      (should (equal (car (nth 0 result)) "py"))
      (should (= (cdr (nth 0 result)) 3))
      (should (equal (car (nth 1 result)) "js"))
      (should (= (cdr (nth 1 result)) 2))
      (should (equal (car (nth 2 result)) "el"))
      (should (= (cdr (nth 2 result)) 1)))))

;;; ── workbench--dashboard-cicd ──────────────────────────────────────────────

(ert-deftest dashboard-cicd/parses-drone-yml ()
  (workbench-test-with-temp-dir dir
    (with-temp-file (expand-file-name ".drone.yml" dir)
      (insert "kind: pipeline\nname: build-and-test\n\nsteps:\n  - name: lint\n    image: python:3.11\n    commands:\n      - make lint\n\n  - name: test\n    image: python:3.11\n    commands:\n      - make test\n\ntrigger:\n  event:\n    - push\n    - pull_request\n"))
    (let ((result (workbench--dashboard-cicd dir)))
      (should result)
      (should (equal (plist-get result :source) ".drone.yml"))
      (should (equal (plist-get result :pipeline) "build-and-test"))
      (should (equal (plist-get result :steps) '("lint" "test")))
      (should (equal (plist-get result :trigger) '("push" "pull_request"))))))

(ert-deftest dashboard-cicd/returns-nil-when-no-drone-yml ()
  (workbench-test-with-temp-dir dir
    (should-not (workbench--dashboard-cicd dir))))

;;; ── workbench-cc--darken ───────────────────────────────────────────────────

(ert-deftest cc-darken/darkens-white-by-half ()
  (should (equal (workbench-cc--darken "#ffffff" 0.5) "#808080")))

(ert-deftest cc-darken/darkens-colour-correctly ()
  ;; #ff8040 darkened by 0.25 → r=255*0.75=191, g=128*0.75=96, b=64*0.75=48
  (should (equal (workbench-cc--darken "#ff8040" 0.25) "#bf6030")))

(ert-deftest cc-darken/zero-amount-no-change ()
  (should (equal (workbench-cc--darken "#aabbcc" 0.0) "#aabbcc")))

(ert-deftest cc-darken/full-amount-returns-black ()
  (should (equal (workbench-cc--darken "#aabbcc" 1.0) "#000000")))

(ert-deftest cc-darken/handles-nil-input ()
  (should (equal (workbench-cc--darken nil 0.5) "#333333")))

(ert-deftest cc-darken/handles-invalid-non-hex-input ()
  (should (equal (workbench-cc--darken "not-a-colour" 0.5) "not-a-colour")))

;;; ── workbench-cc--lighten ──────────────────────────────────────────────────

(ert-deftest cc-lighten/lightens-black-by-half ()
  ;; #000000 lightened by 0.5 → r=0+(255-0)*0.5=128, same for g,b
  (should (equal (workbench-cc--lighten "#000000" 0.5) "#808080")))

(ert-deftest cc-lighten/lightens-colour-correctly ()
  ;; #804020 lightened by 0.5 → r=128+(255-128)*0.5=192, g=64+(255-64)*0.5=160, b=32+(255-32)*0.5=144
  (should (equal (workbench-cc--lighten "#804020" 0.5) "#c0a090")))

(ert-deftest cc-lighten/zero-amount-no-change ()
  (should (equal (workbench-cc--lighten "#aabbcc" 0.0) "#aabbcc")))

(ert-deftest cc-lighten/full-amount-returns-white ()
  (should (equal (workbench-cc--lighten "#000000" 1.0) "#ffffff")))

(ert-deftest cc-lighten/handles-nil-input ()
  (should (equal (workbench-cc--lighten nil 0.5) "#444444")))

;;; test-dashboard.el ends here
