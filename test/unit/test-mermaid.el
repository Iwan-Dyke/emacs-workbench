;;; test/unit/test-mermaid.el --- Unit tests for tools/mermaid.el -*- lexical-binding: t; -*-

(require 'test-helper)

;;; ── Stubs ──────────────────────────────────────────────────────────────────

;; Provide ob-mermaid and mermaid-mode features so after! blocks fire
(provide 'ob-mermaid)
(provide 'mermaid-mode)

;; Stub org-babel-do-load-languages (called at load time via after! org)
(defvar org-babel-load-languages '((emacs-lisp . t))
  "Test stub for org-babel-load-languages.")

(defvar workbench-test--babel-load-called nil
  "Whether org-babel-do-load-languages was called.")

(defun org-babel-do-load-languages (_sym _langs)
  "Stub — record that babel languages were loaded."
  (setq workbench-test--babel-load-called t))

;; Provide org so the after! org block fires
(provide 'org)

;;; ── Load Module ────────────────────────────────────────────────────────────

(workbench-test-load-module "modules/tools/mermaid")

;;; ── ob-mermaid Tests ───────────────────────────────────────────────────────

(ert-deftest mermaid/babel-mermaid-language-registered ()
  "Mermaid should be registered in org-babel-load-languages."
  (should (assoc 'mermaid org-babel-load-languages)))

(ert-deftest mermaid/babel-mermaid-language-enabled ()
  "Mermaid language entry should be enabled (t)."
  (should (eq t (cdr (assoc 'mermaid org-babel-load-languages)))))

(ert-deftest mermaid/babel-load-languages-called ()
  "org-babel-do-load-languages should be called to register mermaid."
  (should workbench-test--babel-load-called))

(ert-deftest mermaid/babel-existing-languages-preserved ()
  "Existing babel languages should not be removed when mermaid is added."
  (should (assoc 'emacs-lisp org-babel-load-languages)))

(ert-deftest mermaid/ob-mermaid-cli-path-set ()
  "ob-mermaid-cli-path should be set (either found or fallback to \"mmdc\")."
  (should (stringp ob-mermaid-cli-path))
  (should (not (string-empty-p ob-mermaid-cli-path))))

(ert-deftest mermaid/ob-mermaid-cli-path-is-mmdc ()
  "ob-mermaid-cli-path should end with 'mmdc' regardless of full path."
  (should (string-suffix-p "mmdc" ob-mermaid-cli-path)))

(ert-deftest mermaid/ob-mermaid-output-format ()
  "ob-mermaid default output should be png for inline display."
  (should (equal ob-mermaid-output "png")))

;;; ── mermaid-mode Tests ─────────────────────────────────────────────────────

(ert-deftest mermaid/mode-mmdc-location-set ()
  "mermaid-mmdc-location should be set."
  (should (stringp mermaid-mmdc-location))
  (should (not (string-empty-p mermaid-mmdc-location))))

(ert-deftest mermaid/mode-mmdc-location-is-mmdc ()
  "mermaid-mmdc-location should point to mmdc."
  (should (string-suffix-p "mmdc" mermaid-mmdc-location)))

(ert-deftest mermaid/mode-output-format ()
  "mermaid-mode output format should be .png."
  (should (equal mermaid-output-format ".png")))

;;; ── Feature Provide ────────────────────────────────────────────────────────

(ert-deftest mermaid/provides-feature ()
  "Module should provide workbench-mermaid feature."
  (should (featurep 'workbench-mermaid)))

;;; test-mermaid.el ends here
