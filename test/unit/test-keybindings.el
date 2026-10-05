;;; test/unit/test-keybindings.el --- Tests for system/keybindings.el -*- lexical-binding: t; -*-

;; In batch, Doom's `map!' is stubbed to a no-op (see test-helper.el), so the
;; actual keymap entries created by `map!' cannot be asserted here — those are
;; covered by the behaviour suite against a live daemon. What IS observable in
;; batch is `evil-set-initial-state', which the vterm block calls to keep
;; interactive TUIs (kiro-cli, claude, /usage) in insert state so bare keys
;; reach the process instead of being eaten by evil.

(require 'ert)
(require 'cl-lib)
(require 'test-helper)

;; keybindings.el references a large evil/Doom keymap surface via `define-key'
;; and `general-define-key'. In batch none of that is loaded, so stub the
;; state-map variables and general macro as inert targets. We are not asserting
;; those bindings here (the live-daemon behaviour suite does that) — we only
;; need the file to load so we can observe the `evil-set-initial-state' call.
(dolist (map-sym '(evil-normal-state-map evil-visual-state-map
                   evil-motion-state-map evil-emacs-state-map
                   vterm-mode-map treemacs-mode-map org-agenda-mode-map
                   doom-leader-map))
  (unless (boundp map-sym)
    (set map-sym (make-sparse-keymap))))

(unless (fboundp 'general-define-key)
  (defun general-define-key (&rest _) nil))
(unless (fboundp 'evil-window-down) (defun evil-window-down () (interactive)))
(unless (fboundp 'evil-window-up) (defun evil-window-up () (interactive)))
(defvar vterm-keymap-exceptions nil)

;;; ── vterm initial evil state ────────────────────────────────────────────────

(ert-deftest keybindings/vterm-starts-in-insert-state ()
  "Loading keybindings.el sets vterm-mode's initial evil state to insert.
This is what lets Esc/normal keys reach a running TUI (Kiro /usage) instead
of being intercepted by evil normal state."
  (let ((calls '()))
    (cl-letf (((symbol-function 'evil-set-initial-state)
               (lambda (mode state) (push (cons mode state) calls))))
      (workbench-test-load-module "modules/system/keybindings.el")
      (should (equal (cdr (assq 'vterm-mode calls)) 'insert)))))

(provide 'test-keybindings)
;;; test-keybindings.el ends here
