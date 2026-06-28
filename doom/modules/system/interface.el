;;; system/interface.el -*- lexical-binding: t; -*-

(declare-function treemacs-get-local-window "treemacs-core-utils")

;; ── Theming ─────────────────────────────────────────────────────────────────

(add-to-list 'custom-theme-load-path
             (expand-file-name "themes/" doom-user-dir))

(defvar workbench/themes
  '(workbench-wayne-tech workbench-matrix)
  "List of workbench themes available for switching.")

(defvar workbench/default-theme nil
  "Default theme for the active profile. Set by profile files.")

(defun workbench/switch-theme ()
  "Switch between workbench themes interactively."
  (interactive)
  (let ((theme (intern (completing-read "Theme: "
                         (mapcar #'symbol-name workbench/themes)
                         nil t))))
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme theme t)
    (message "Switched to %s" theme)))

(defun workbench--apply-default-theme ()
  "Apply the profile default theme if set."
  (when workbench/default-theme
    (mapc #'disable-theme custom-enabled-themes)
    (load-theme workbench/default-theme t)))

;; ── Frame ───────────────────────────────────────────────────────────────────

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
    (enlarge-window-horizontally workbench/resize-step))
  (workbench--resize-message))

(defun workbench/resize-right ()
  "Move the selected window's vertical divider right by `workbench/resize-step'."
  (interactive)
  (if (window-in-direction 'right)
      (enlarge-window-horizontally workbench/resize-step)
    (shrink-window-horizontally workbench/resize-step))
  (workbench--resize-message))

(defun workbench/resize-down ()
  "Move the selected window's horizontal divider down by `workbench/resize-step'."
  (interactive)
  (if (window-in-direction 'below)
      (enlarge-window workbench/resize-step)
    (shrink-window workbench/resize-step))
  (workbench--resize-message))

(defun workbench/resize-up ()
  "Move the selected window's horizontal divider up by `workbench/resize-step'."
  (interactive)
  (if (window-in-direction 'below)
      (shrink-window workbench/resize-step)
    (enlarge-window workbench/resize-step))
  (workbench--resize-message))

(defun workbench--resize-message ()
  "Show the resize mode indicator."
  (message "Resize: h/l width  j/k height  = balance  (any other key exits)"))

(defvar workbench-resize-map
  (let ((map (make-sparse-keymap)))
    (define-key map "h" #'workbench/resize-left)
    (define-key map "l" #'workbench/resize-right)
    (define-key map "j" #'workbench/resize-down)
    (define-key map "k" #'workbench/resize-up)
    (define-key map "=" (lambda () (interactive) (balance-windows) (workbench--resize-message)))
    map)
  "Transient keymap for repeatable window resizing.")

(defun workbench/resize-mode ()
  "Enter a transient window-resize state.
Tap h/l to adjust width and j/k to adjust height, repeatedly; = balances
all windows; any other key (e.g. ESC) exits."
  (interactive)
  (workbench--resize-message)
  (set-transient-map workbench-resize-map t
                     (lambda () (message "Resize done"))))

;; Apply the profile default theme after all modules have loaded.
(add-hook 'doom-init-ui-hook #'workbench--apply-default-theme)
