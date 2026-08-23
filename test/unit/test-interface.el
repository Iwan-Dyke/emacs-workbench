;;; test/unit/test-interface.el --- Tests for interface module -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'test-helper)

(workbench-test-load-module "modules/system/interface.el")

;;; ── Resize mode ────────────────────────────────────────────────────────────

(ert-deftest interface/resize-mode-sets-overriding-map ()
  "Entering resize mode activates the transient map (set-transient-map called)."
  (let ((called nil))
    (cl-letf (((symbol-function 'set-transient-map)
               (lambda (map &rest _) (setq called map))))
      (workbench/resize-mode)
      (should (eq called workbench-resize-map)))))

(ert-deftest interface/resize-exit-via-on-exit-callback ()
  "The on-exit callback in set-transient-map prints 'Resize done'."
  (let ((on-exit nil))
    (cl-letf (((symbol-function 'set-transient-map)
               (lambda (_map _keep-p exit-fn) (setq on-exit exit-fn))))
      (workbench/resize-mode)
      (should (functionp on-exit))
      (let ((msg nil))
        (cl-letf (((symbol-function 'message) (lambda (fmt &rest _) (setq msg fmt))))
          (funcall on-exit)
          (should (string= msg "Resize done")))))))

(ert-deftest interface/resize-map-has-h-l-j-k ()
  "Resize map binds h, l, j, k."
  (should (eq (lookup-key workbench-resize-map "h") #'workbench/resize-left))
  (should (eq (lookup-key workbench-resize-map "l") #'workbench/resize-right))
  (should (eq (lookup-key workbench-resize-map "j") #'workbench/resize-down))
  (should (eq (lookup-key workbench-resize-map "k") #'workbench/resize-up)))

(ert-deftest interface/resize-map-no-exit-bindings ()
  "Resize map does NOT bind C-g or escape (they exit via transient-map deactivation)."
  (should-not (lookup-key workbench-resize-map (kbd "C-g")))
  (should-not (lookup-key workbench-resize-map [escape])))

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
