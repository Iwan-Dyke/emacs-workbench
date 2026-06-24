;;; system/interface.el -*- lexical-binding: t; -*-

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
