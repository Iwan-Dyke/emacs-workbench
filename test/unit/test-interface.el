;;; test/unit/test-interface.el --- Tests for interface module -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'test-helper)

(workbench-test-load-module "modules/system/interface.el")

;;; ── Resize mode ────────────────────────────────────────────────────────────

(ert-deftest interface/resize-mode-sets-overriding-map ()
  "Entering resize mode sets overriding-terminal-local-map."
  (workbench/resize-mode)
  (unwind-protect
      (should (eq overriding-terminal-local-map workbench-resize-map))
    (setq overriding-terminal-local-map nil)))

(ert-deftest interface/resize-exit-clears-map ()
  "Exiting resize mode clears overriding-terminal-local-map."
  (setq overriding-terminal-local-map workbench-resize-map)
  (workbench--resize-exit)
  (should (null overriding-terminal-local-map)))

(ert-deftest interface/resize-map-has-h-l-j-k ()
  "Resize map binds h, l, j, k."
  (should (eq (lookup-key workbench-resize-map "h") #'workbench/resize-left))
  (should (eq (lookup-key workbench-resize-map "l") #'workbench/resize-right))
  (should (eq (lookup-key workbench-resize-map "j") #'workbench/resize-down))
  (should (eq (lookup-key workbench-resize-map "k") #'workbench/resize-up)))

(ert-deftest interface/resize-map-has-default-exit ()
  "Resize map has [t] binding for exit on unknown key."
  (should (eq (lookup-key workbench-resize-map [t]) #'workbench--resize-exit)))

(ert-deftest interface/resize-map-has-balance ()
  "Resize map has = for balance-windows."
  (should (lookup-key workbench-resize-map "=")))

;;; ── Window navigation ──────────────────────────────────────────────────────

(ert-deftest interface/window-left-is-interactive ()
  "workbench/window-left is an interactive command."
  (should (commandp #'workbench/window-left)))

(ert-deftest interface/window-right-is-interactive ()
  "workbench/window-right is an interactive command."
  (should (commandp #'workbench/window-right)))

(ert-deftest interface/resize-mode-is-interactive ()
  "workbench/resize-mode is an interactive command."
  (should (commandp #'workbench/resize-mode)))

;;; ── Theme switching ────────────────────────────────────────────────────────

(ert-deftest interface/themes-list-defined ()
  "workbench/themes contains available themes."
  (should (listp workbench/themes))
  (should (memq 'workbench-wayne-tech workbench/themes))
  (should (memq 'workbench-matrix workbench/themes)))

(ert-deftest interface/switch-theme-is-interactive ()
  "workbench/switch-theme is an interactive command."
  (should (commandp #'workbench/switch-theme)))

(provide 'test-interface)
;;; test-interface.el ends here
