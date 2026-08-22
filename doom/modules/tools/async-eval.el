;;; tools/async-eval.el -*- lexical-binding: t; -*-

;; Shared async evaluation infrastructure for workbench modules.
;; Spawns a child Emacs in batch mode to evaluate a form, parses the
;; result via `read', and calls a callback with the parsed sexp (or nil
;; on failure). Handles process lifecycle, timeout, and buffer cleanup.
;;
;; Used by jira.el (async cache refresh) and command-centre.el (async
;; data collection).

;;; ── State ──────────────────────────────────────────────────────────────────

(defvar workbench-async--processes (make-hash-table :test 'eq)
  "Map of caller-key → (process . timeout-timer) for tracking in-flight evals.")

;;; ── Public API ─────────────────────────────────────────────────────────────

(defun workbench-async-eval (key form callback &optional timeout name)
  "Evaluate FORM in a child Emacs batch process and call CALLBACK with the result.

KEY is a symbol identifying this async operation (e.g. \\='jira or \\='cc).
If an operation with the same KEY is already in flight, it is killed first.

FORM is an unquoted Emacs Lisp expression. It will be serialized via
`prin1-to-string' and passed to `emacs --batch --eval'. The form MUST
call `(prin1 result)' as its final expression to produce output.

CALLBACK receives one argument: the parsed sexp from the child's stdout,
or nil if the process failed, timed out, or produced unparseable output.

TIMEOUT is the number of seconds before killing the child (default 60).
NAME is a human-readable label for log messages (default: KEY symbol name)."
  (let* ((timeout-secs (or timeout 60))
         (label (or name (symbol-name key)))
         (existing (gethash key workbench-async--processes)))
    ;; Kill any in-flight process for this key
    (when existing
      (let ((proc (car existing))
            (timer (cdr existing)))
        (when (and proc (process-live-p proc))
          (delete-process proc))
        (when (timerp timer)
          (cancel-timer timer)))
      (remhash key workbench-async--processes))
    ;; Spawn child Emacs
    (let* ((emacs-bin (expand-file-name invocation-name invocation-directory))
           (output-buf (generate-new-buffer (format " *%s-async*" label)))
           (proc (make-process
                  :name (format "%s-async" label)
                  :buffer output-buf
                  :command (list emacs-bin "--batch" "--eval"
                                (prin1-to-string form))
                  :noquery t
                  :sentinel
                  (lambda (process _event)
                    (when (memq (process-status process) '(exit signal))
                      ;; Cancel timeout
                      (let ((entry (gethash key workbench-async--processes)))
                        (when (and entry (timerp (cdr entry)))
                          (cancel-timer (cdr entry))))
                      (unwind-protect
                          (let ((result nil))
                            (when (zerop (process-exit-status process))
                              (when (buffer-live-p (process-buffer process))
                                (with-current-buffer (process-buffer process)
                                  (goto-char (point-min))
                                  (condition-case nil
                                      (setq result (read (current-buffer)))
                                    (error
                                     (message "%s: failed to parse output"
                                              label))))))
                            (when (not (zerop (process-exit-status process)))
                              (message "%s: process exited %d"
                                       label (process-exit-status process)))
                            (remhash key workbench-async--processes)
                            (condition-case err
                                (funcall callback result)
                              (error
                               (message "%s: callback error: %s"
                                        label (error-message-string err)))))
                        ;; Always kill the output buffer
                        (when (buffer-live-p (process-buffer process))
                          (kill-buffer (process-buffer process))))))))
           ;; Timeout timer
           (timer (run-at-time
                   timeout-secs nil
                   (lambda ()
                     (when (and (process-live-p proc)
                                (let ((entry (gethash key workbench-async--processes)))
                                  (and entry (eq (car entry) proc))))
                       (message "%s: timed out after %ds" label timeout-secs)
                       (delete-process proc))))))
      ;; Track state
      (puthash key (cons proc timer) workbench-async--processes))))

(provide 'workbench-async-eval)
;;; tools/async-eval.el ends here
