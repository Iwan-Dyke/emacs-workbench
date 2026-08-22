;;; tools/shell.el -*- lexical-binding: t; -*-

;; Shared shell execution helpers for workbench modules.
;; All process execution goes through these functions to ensure consistent
;; behaviour: call-process (no shell interpolation), trimmed output, nil on
;; failure. Used by jira.el, command-centre-data.el, project-dashboard-data.el,
;; and repos-data.el.

(defun workbench-shell (dir &rest args)
  "Run ARGS as a process in DIR, return trimmed stdout or nil on failure.
DIR defaults to ~/ when nil. Returns nil when the command fails OR when
stdout is empty. Uses `call-process' (exec, not shell) so arguments are
never subject to shell interpolation."
  (let ((default-directory (expand-file-name (or dir "~/"))))
    (with-temp-buffer
      (when (zerop (apply #'call-process (car args) nil t nil (cdr args)))
        (let ((output (string-trim (buffer-string))))
          (unless (string-empty-p output) output))))))

(defun workbench-shell-lines (dir &rest args)
  "Run ARGS in DIR, return non-empty stdout lines as a list.
Returns nil when the command fails or produces no output."
  (when-let ((out (apply #'workbench-shell dir args)))
    (split-string out "\n" t)))

(defun workbench-shell-or-error (dir &rest args)
  "Run ARGS in DIR. Return (:ok OUTPUT) or (:error REASON).
Checks that the command exists before attempting execution."
  (let ((default-directory (expand-file-name (or dir "~/")))
        (cmd (car args)))
    (if (not (executable-find cmd))
        (list :error (format "%s not found" cmd))
      (with-temp-buffer
        (let ((exit (apply #'call-process cmd nil t nil (cdr args))))
          (if (zerop exit)
              (list :ok (string-trim (buffer-string)))
            (list :error (format "%s exited %d" cmd exit))))))))

(provide 'workbench-shell)
;;; tools/shell.el ends here
