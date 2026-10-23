;;; test/unit/test-async-eval.el --- Tests for tools/async-eval.el -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'test-helper)

;; async-eval is loaded as a foundational module by test-helper.

;;; ── TestExtractResult ───────────────────────────────────────────────────────
;; Parsing the result sexp out of raw child stdout, which may carry noise
;; (obsolete-macro warnings, `message' output) before the result.

(ert-deftest async-eval/extract/clean-output ()
  "Reads the result sexp when stdout contains only the wrapped result."
  (let ((text (concat "\n" workbench-async--result-begin "\n"
                      "(:repos 3 :dirty 1)\n"
                      workbench-async--result-end "\n")))
    (should (equal (workbench-async--extract-result text)
                   '(:repos 3 :dirty 1)))))

(ert-deftest async-eval/extract/ignores-leading-warning-noise ()
  "Leading warning noise before the sentinel is ignored; result parses correctly.
This is the regression: in Emacs 31.1 loading a module emits an obsolete-macro
warning to stdout, which the old point-min `read' mistook for the result."
  (let ((text (concat
               ".config/doom/modules/tools/shell.el: Warning: 'when-let' is an "
               "obsolete macro (as of 31.1); use 'when-let*' instead.\n"
               "Some other message line\n"
               "\n" workbench-async--result-begin "\n"
               "(:ok t :count 42)\n"
               workbench-async--result-end "\n")))
    (should (equal (workbench-async--extract-result text)
                   '(:ok t :count 42)))))

(ert-deftest async-eval/extract/list-of-plists ()
  "Reads a list result (as the repos scan produces) despite leading noise."
  (let ((text (concat "warning: something noisy\n"
                      "\n" workbench-async--result-begin "\n"
                      "((:name \"a\" :state clean) (:name \"b\" :state dirty))\n"
                      workbench-async--result-end "\n")))
    (should (equal (workbench-async--extract-result text)
                   '((:name "a" :state clean) (:name "b" :state dirty))))))

(ert-deftest async-eval/extract/missing-sentinel-returns-nil ()
  "Output without the start sentinel yields nil (treated as unparseable)."
  (should (null (workbench-async--extract-result
                 "just a warning, no result sentinel here")))
  (should (null (workbench-async--extract-result ""))))

(ert-deftest async-eval/extract/non-string-returns-nil ()
  "Non-string input yields nil rather than erroring."
  (should (null (workbench-async--extract-result nil))))

(ert-deftest async-eval/extract/reads-only-first-sexp ()
  "Only the single sexp following the start sentinel is read."
  (let ((text (concat "\n" workbench-async--result-begin "\n"
                      "(:a 1) (:b 2)\n"
                      workbench-async--result-end "\n")))
    (should (equal (workbench-async--extract-result text) '(:a 1)))))

;;; ── TestAsyncEval ────────────────────────────────────────────────────────────
;; End-to-end: spawn a real child Emacs and confirm the callback receives the
;; parsed value even when the child prints noise before `(prin1 result)'.

(defun async-eval/wait-for (pred &optional timeout)
  "Block up to TIMEOUT seconds until PRED returns non-nil. Returns PRED's value."
  (let ((deadline (+ (float-time) (or timeout 20)))
        (val nil))
    (while (and (not (setq val (funcall pred)))
                (< (float-time) deadline))
      (accept-process-output nil 0.1)
      (sit-for 0.05))
    val))

(ert-deftest async-eval/callback-receives-parsed-result ()
  "A child whose stdout carries leading noise still yields the parsed result."
  (let ((done nil)
        (received 'unset))
    (workbench-async-eval
     'test-noise
     ;; FORM returns the value (new contract). It also writes noise to stdout
     ;; first, mimicking an obsolete-macro warning emitted while FORM runs.
     '(progn
        (princ "Warning: 'when-let' is an obsolete macro (as of 31.1)\n")
        (list :ok t :n 7))
     (lambda (result)
       (setq received result done t))
     20 "test-noise")
    (async-eval/wait-for (lambda () done))
    (should done)
    (should (equal received '(:ok t :n 7)))))

(ert-deftest async-eval/callback-nil-when-form-returns-nil ()
  "A child whose FORM returns nil yields nil to the callback (round-trips)."
  (let ((done nil)
        (received 'unset))
    (workbench-async-eval
     'test-nil
     '(progn
        (princ "some noisy warning before the result\n")
        nil)
     (lambda (result)
       (setq received result done t))
     20 "test-nil")
    (async-eval/wait-for (lambda () done))
    (should done)
    (should (null received))))

(provide 'test-async-eval)
;;; test/unit/test-async-eval.el ends here
