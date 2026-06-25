;;; system/interface.el -*- lexical-binding: t; -*-

;; Open frames maximized so the workbench fills the screen. The
;; default-frame-alist entry covers a plain `emacs'; the hook covers
;; emacsclient frames created against the workbench daemon, which do not
;; reliably honor default-frame-alist.
(add-to-list 'default-frame-alist '(fullscreen . maximized))

(defun workbench--maximize-frame (&optional frame)
  "Maximize FRAME, or the selected frame."
  (set-frame-parameter (or frame (selected-frame)) 'fullscreen 'maximized))

(add-hook 'server-after-make-frame-hook #'workbench--maximize-frame)

(defun workbench--treemacs-window ()
  "Return the visible Treemacs window in this frame, or nil."
  (and (fboundp 'treemacs-get-local-window)
       (treemacs-get-local-window)))

(defun workbench/window-left ()
  "Move to the window on the left.
If there is none but Treemacs is open, jump into the Treemacs tree."
  (interactive)
  (condition-case nil
      (windmove-left)
    (error
     (let ((tree (workbench--treemacs-window)))
       (when (and tree (not (eq tree (selected-window))))
         (select-window tree))))))

(defun workbench/window-right ()
  "Move to the window on the right.
From the Treemacs tree, return to the editing window."
  (interactive)
  (condition-case nil
      (windmove-right)
    (error
     (when (eq (selected-window) (workbench--treemacs-window))
       (other-window 1)))))

;; Window resizing. The default Emacs/Doom resize bindings are one-shot chords,
;; which makes meaningful resizing tedious. Enter a transient resize state, then
;; tap bare h/j/k/l to resize the selected window repeatedly until you press a
;; key outside the map (e.g. ESC). The keys mirror the C-h/j/k/l navigation.

(defvar workbench/resize-step 4
  "Number of columns or lines each resize keypress adjusts a window by.")

;; Resize directionally: h/l move the vertical divider left/right and j/k move
;; the horizontal divider down/up, regardless of which window is selected. A
;; plain enlarge/shrink would feel inverted in a window docked on the right or
;; bottom (e.g. the AI pane), because there \"grow\" pulls the divider the other
;; way. Keying off the neighbor in each direction keeps the divider moving the
;; way you press.

(defun workbench/resize-left ()
  "Move the selected window's vertical divider left by `workbench/resize-step'."
  (interactive)
  (if (window-in-direction 'right)
      (shrink-window-horizontally workbench/resize-step)
    (enlarge-window-horizontally workbench/resize-step)))

(defun workbench/resize-right ()
  "Move the selected window's vertical divider right by `workbench/resize-step'."
  (interactive)
  (if (window-in-direction 'right)
      (enlarge-window-horizontally workbench/resize-step)
    (shrink-window-horizontally workbench/resize-step)))

(defun workbench/resize-down ()
  "Move the selected window's horizontal divider down by `workbench/resize-step'."
  (interactive)
  (if (window-in-direction 'below)
      (enlarge-window workbench/resize-step)
    (shrink-window workbench/resize-step)))

(defun workbench/resize-up ()
  "Move the selected window's horizontal divider up by `workbench/resize-step'."
  (interactive)
  (if (window-in-direction 'below)
      (shrink-window workbench/resize-step)
    (enlarge-window workbench/resize-step)))

(defvar workbench-resize-map
  (let ((map (make-sparse-keymap)))
    (define-key map "h" #'workbench/resize-left)
    (define-key map "l" #'workbench/resize-right)
    (define-key map "j" #'workbench/resize-down)
    (define-key map "k" #'workbench/resize-up)
    (define-key map "=" #'balance-windows)
    map)
  "Transient keymap for repeatable window resizing.")

(defun workbench/resize-mode ()
  "Enter a transient window-resize state.
Tap h/l to adjust width and j/k to adjust height, repeatedly; = balances
all windows; any other key (e.g. ESC) exits."
  (interactive)
  (message "Resize: h/l width  j/k height  = balance  (any other key exits)")
  (set-transient-map workbench-resize-map t
                     (lambda () (message "Resize done"))))
