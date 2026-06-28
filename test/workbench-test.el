;;; workbench-test.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)

;;; Functions under test — extracted from source to avoid Doom dependencies.

(defun workbench--directory-name (directory)
  "Return a workspace-friendly name for DIRECTORY."
  (file-name-nondirectory (directory-file-name directory)))

(defvar workbench--popup-terminal-configs (make-hash-table :test 'equal))

(defun workbench--project-identity-name (directory)
  "Return a workspace name for DIRECTORY, deduplicating on collision."
  (let* ((path (directory-file-name (file-truename directory)))
         (base (file-name-nondirectory path)))
    (if (or (not (fboundp '+workspace-exists-p))
            (not (+workspace-exists-p base)))
        base
      (let ((existing-dir
             (when-let ((buf (get-buffer (format "*workbench:%s*" base))))
               (buffer-local-value 'default-directory buf))))
        (if (and existing-dir (string= (file-truename existing-dir) path))
            base
          (let ((n 2) candidate)
            (while (progn
                     (setq candidate (format "%s<%d>" base n))
                     (+workspace-exists-p candidate))
              (setq n (1+ n)))
            candidate))))))

(defun workbench/toggle-popup-terminal ()
  "Toggle a popup terminal scoped to the current workspace."
  (interactive)
  (let ((ws (+workspace-current-name)))
    (if (gethash ws workbench--popup-terminal-configs)
        (let ((config (gethash ws workbench--popup-terminal-configs)))
          (remhash ws workbench--popup-terminal-configs)
          (when (window-configuration-p config)
            (set-window-configuration config)))
      (puthash ws (current-window-configuration) workbench--popup-terminal-configs)
      (let ((ignore-window-parameters t))
        (delete-other-windows))
      (switch-to-buffer (workbench--popup-terminal-buffer)))))

;;; Tests — workbench--directory-name

(ert-deftest workbench--directory-name/extracts-last-component ()
  (should (equal (workbench--directory-name "/home/user/projects/foo") "foo")))

(ert-deftest workbench--directory-name/handles-trailing-slash ()
  (should (equal (workbench--directory-name "/home/user/projects/bar/") "bar")))

;;; Tests — workbench--project-identity-name

(ert-deftest workbench--project-identity-name/bare-name-no-collision ()
  (cl-letf (((symbol-function '+workspace-exists-p) (lambda (_) nil)))
    (should (equal (workbench--project-identity-name "/tmp/myproject")
                   "myproject"))))

(ert-deftest workbench--project-identity-name/same-dir-returns-same-name ()
  "Reopening the same directory reuses the existing workspace name."
  (let ((dir (make-temp-file "wb-test-" t)))
    (unwind-protect
        (let ((buf (get-buffer-create
                    (format "*workbench:%s*" (file-name-nondirectory dir)))))
          (with-current-buffer buf
            (setq-local default-directory (file-name-as-directory dir)))
          (cl-letf (((symbol-function '+workspace-exists-p) (lambda (_) t)))
            (should (equal (workbench--project-identity-name dir)
                           (file-name-nondirectory dir))))
          (kill-buffer buf))
      (delete-directory dir t))))

(ert-deftest workbench--project-identity-name/collision-appends-suffix ()
  "Different directory with same base name gets <2> suffix."
  (let* ((dir-a (make-temp-file "wb-col-" t))
         (base (file-name-nondirectory dir-a))
         (buf (get-buffer-create (format "*workbench:%s*" base))))
    (unwind-protect
        (progn
          (with-current-buffer buf
            (setq-local default-directory (file-name-as-directory dir-a)))
          (cl-letf (((symbol-function '+workspace-exists-p)
                     (lambda (name) (equal name base))))
            (let ((other-dir (concat "/other/" base)))
              (should (equal (workbench--project-identity-name other-dir)
                             (format "%s<2>" base))))))
      (kill-buffer buf)
      (delete-directory dir-a t))))

;;; Tests — workbench/toggle-popup-terminal

(ert-deftest workbench/toggle-popup-terminal/on-stores-config ()
  "Toggling on stores window config in the hash table."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal)))
    (cl-letf (((symbol-function '+workspace-current-name) (lambda () "test-ws"))
              ((symbol-function 'workbench--popup-terminal-buffer)
               (lambda () (get-buffer-create "*test-popup*")))
              ((symbol-function 'delete-other-windows) #'ignore))
      (workbench/toggle-popup-terminal)
      (should (gethash "test-ws" workbench--popup-terminal-configs))
      (kill-buffer "*test-popup*"))))

(ert-deftest workbench/toggle-popup-terminal/off-removes-config ()
  "Toggling off removes the entry from the hash table."
  (let ((workbench--popup-terminal-configs (make-hash-table :test 'equal)))
    (puthash "test-ws" (current-window-configuration) workbench--popup-terminal-configs)
    (cl-letf (((symbol-function '+workspace-current-name) (lambda () "test-ws")))
      (workbench/toggle-popup-terminal)
      (should-not (gethash "test-ws" workbench--popup-terminal-configs)))))

;;; workbench-test.el ends here
