;;; tools/async-eval.el -*- lexical-binding: t; -*-

;; Shared async evaluation infrastructure for workbench modules.
;; Spawns a child Emacs in batch mode to evaluate a form, parses the
;; result via `read', and calls a callback with the parsed sexp (or nil
;; on failure). Handles process lifecycle, timeout, and buffer cleanup.
;;
;; The child's stdout can contain arbitrary noise before the result:
;; obsolete-macro warnings (e.g. `when-let' in Emacs 31.1), `message'
;; output, or byte-compile chatter. To parse the result unambiguously,
;; the child is wrapped so it prints a start sentinel, then the result,
;; then an end sentinel. The parent reads the single sexp that follows
;; the start sentinel and ignores everything before it.
;;
;; Used by jira.el (async cache refresh) and command-centre.el (async
;; data collection).

;;; ── State ──────────────────────────────────────────────────────────────────

(defvar workbench-async--processes (make-hash-table :test 'eq)
  "Map of caller-key → (process . timeout-timer) for tracking in-flight evals.")

(defconst workbench-async--result-begin "WORKBENCH-ASYNC-RESULT-BEGIN"
  "Sentinel printed by the child immediately before the result sexp.")

(defconst workbench-async--result-end "WORKBENCH-ASYNC-RESULT-END"
  "Sentinel printed by the child immediately after the result sexp.")

;;; ── Result parsing ─────────────────────────────────────────────────────────

(defun workbench-async--wrap-form (form)
  "Wrap FORM so the child prints its value between unique sentinels.
FORM is evaluated for its VALUE (it must no longer print the result
itself). The wrapper prints the start sentinel, then the value via
`prin1', then the end sentinel. Because the sentinels bracket only the
`prin1' of the final value, any stray stdout emitted while FORM runs
\(obsolete-macro warnings, `message' output) lands before the start
sentinel and is ignored by the parent."
  `(progn
     (let ((workbench-async--value (progn ,form)))
       (princ ,(concat "\n" workbench-async--result-begin "\n"))
       (prin1 workbench-async--value)
       (princ ,(concat "\n" workbench-async--result-end "\n")))))

(defun workbench-async--extract-result (text)
  "Extract and read the result sexp from child stdout TEXT.
Reads the single sexp between the start and end sentinels, ignoring any
leading noise. Returns the parsed value, or nil if the sentinels are
absent or the delimited region cannot be read as a sexp."
  (when (stringp text)
    (let ((start (string-search workbench-async--result-begin text)))
      (when start
        (let* ((from (+ start (length workbench-async--result-begin)))
               (end (string-search workbench-async--result-end text from))
               (body (substring text from (or end (length text)))))
          (condition-case nil
              (car (read-from-string body))
            (error nil)))))))

;;; ── Public API ─────────────────────────────────────────────────────────────

(defun workbench-async-eval (key form callback &optional timeout name)
  "Evaluate FORM in a child Emacs batch process and call CALLBACK with the result.

KEY is a symbol identifying this async operation (e.g. \\='jira or \\='cc).
If an operation with the same KEY is already in flight, it is killed first.

FORM is an unquoted Emacs Lisp expression. It will be serialized via
`prin1-to-string' and passed to `emacs --batch --eval'. FORM is
evaluated for its VALUE: its final expression must produce the result
to return (do NOT call `prin1' yourself — the wrapper prints the value
between unique sentinels so the parent can parse it despite stray
stdout noise such as warnings or `message' output).

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
           (proc nil)
           (timer nil))
      (condition-case err
          (setq proc (make-process
                      :name (format "%s-async" label)
                      :buffer output-buf
                      :command (list emacs-bin "--batch" "--eval"
                                    (prin1-to-string
                                     (workbench-async--wrap-form form)))
                      :noquery t
                      :sentinel
                  (lambda (process _event)
                    (when (memq (process-status process) '(exit signal))
                      ;; Verify this sentinel belongs to the current operation
                      ;; for this key. A rapid re-call may have replaced us.
                      (let ((entry (gethash key workbench-async--processes)))
                        (if (not (and entry (eq process (car entry))))
                            ;; Stale sentinel — just clean up buffer and exit
                            (when (buffer-live-p (process-buffer process))
                              (kill-buffer (process-buffer process)))
                          ;; Active sentinel — proceed
                          (when (timerp (cdr entry))
                            (cancel-timer (cdr entry)))
                          (unwind-protect
                              (let ((result nil))
                                (when (zerop (process-exit-status process))
                                  (when (buffer-live-p (process-buffer process))
                                    (with-current-buffer (process-buffer process)
                                      (setq result
                                            (workbench-async--extract-result
                                             (buffer-string)))
                                      (unless result
                                        (message "%s: failed to parse output"
                                                 label)))))
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
                              (kill-buffer (process-buffer process))))))))))
        (error
         (when (buffer-live-p output-buf)
           (kill-buffer output-buf))
         (message "%s: failed to start process: %s" label (error-message-string err))))
      ;; Timeout timer and state tracking (only when process started)
      (when proc
        (setq timer (run-at-time
                     timeout-secs nil
                     (lambda ()
                       (when (and (process-live-p proc)
                                  (let ((entry (gethash key workbench-async--processes)))
                                    (and entry (eq (car entry) proc))))
                         (message "%s: timed out after %ds" label timeout-secs)
                         (delete-process proc)))))
        (puthash key (cons proc timer) workbench-async--processes)))))

(provide 'workbench-async-eval)
;;; tools/async-eval.el ends here
