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
