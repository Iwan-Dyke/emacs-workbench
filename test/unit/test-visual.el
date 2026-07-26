;;; test/unit/test-visual.el --- Tests for visual enhancement module -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'test-helper)

;; Stub lin-mode since the package won't be installed in batch
(unless (fboundp 'lin-mode)
  (defun lin-mode (&optional _arg) nil))
(unless (boundp 'lin-mode-hooks)
  (defvar lin-mode-hooks nil))
(unless (fboundp 'global-org-modern-mode)
  (defun global-org-modern-mode (&optional _arg) nil))

(workbench-test-load-module "modules/system/visual.el")

;;; ── Lin configuration ──────────────────────────────────────────────────────

(ert-deftest visual/lin-hooks-configured ()
  "Lin mode hooks include workbench custom modes."
  (should (memq 'workbench-repos-mode-hook lin-mode-hooks))
  (should (memq 'workbench-cc-mode-hook lin-mode-hooks)))

(ert-deftest visual/lin-on-repos-mode-hook ()
  "lin-mode is added to workbench-repos-mode-hook."
  (should (memq #'lin-mode (default-value 'workbench-repos-mode-hook))))

(ert-deftest visual/lin-on-cc-mode-hook ()
  "lin-mode is added to workbench-cc-mode-hook."
  (should (memq #'lin-mode (default-value 'workbench-cc-mode-hook))))

;;; ── Hl-line in project dashboard ───────────────────────────────────────────

(ert-deftest visual/hl-line-in-workbench-buffers ()
  "special-mode-hook enables hl-line in *workbench:* buffers."
  ;; The hook adds a lambda that checks buffer name prefix
  (let ((hook-fns (default-value 'special-mode-hook)))
    (should (cl-some #'functionp hook-fns))))

;;; ── Org-modern configuration ───────────────────────────────────────────────

(ert-deftest visual/org-modern-stars-configured ()
  "org-modern-star is set to custom bullet list."
  (should (bound-and-true-p org-modern-star))
  (should (listp org-modern-star))
  (should (= (length org-modern-star) 5)))

(ert-deftest visual/org-modern-checkbox-configured ()
  "org-modern-checkbox is configured with unicode checkboxes."
  (should (bound-and-true-p org-modern-checkbox))
  (should (= (length org-modern-checkbox) 3)))

(ert-deftest visual/org-modern-list-configured ()
  "org-modern-list maps - and + to bullets."
  (should (bound-and-true-p org-modern-list))
  (should (assq ?- org-modern-list))
  (should (assq ?+ org-modern-list)))

(ert-deftest visual/org-modern-table-disabled ()
  "org-modern-table is nil (keep standard org tables)."
  (should-not org-modern-table))

;;; ── Agenda visual tweaks ───────────────────────────────────────────────────

(ert-deftest visual/agenda-block-separator ()
  "Agenda block separator uses a horizontal line character."
  (should (equal org-agenda-block-separator ?─)))

(provide 'test-visual)
;;; test-visual.el ends here
