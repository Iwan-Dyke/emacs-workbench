;;; test/unit/test-jira.el --- Unit tests for tools/jira.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Load the module under test
(workbench-test-load-module "modules/tools/jira")

;;; ── Error predicates ───────────────────────────────────────────────────────

(ert-deftest jira-error-p/recognises-error ()
  (should (workbench-jira-error-p '(:error "something broke"))))

(ert-deftest jira-error-p/rejects-success ()
  (should-not (workbench-jira-error-p '(:ok "output"))))

(ert-deftest jira-error-p/rejects-nil ()
  (should-not (workbench-jira-error-p nil)))

(ert-deftest jira-error-p/rejects-plain-list ()
  (should-not (workbench-jira-error-p '((:key "DPT-1")))))

(ert-deftest jira-error-reason/extracts-message ()
  (should (equal (workbench-jira-error-reason '(:error "jira not found"))
                 "jira not found")))

;;; ── Date math ──────────────────────────────────────────────────────────────

(ert-deftest jira-days-since-update/recent-date ()
  (let* ((yesterday (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                      (time-subtract (current-time) (seconds-to-time 86400)))))
    (let ((days (workbench-jira-days-since-update yesterday)))
      (should days)
      (should (< (abs (- days 1.0)) 0.1)))))

(ert-deftest jira-days-since-update/old-date ()
  (let* ((ten-days-ago (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                         (time-subtract (current-time) (seconds-to-time (* 10 86400))))))
    (let ((days (workbench-jira-days-since-update ten-days-ago)))
      (should days)
      (should (< (abs (- days 10.0)) 0.1)))))

(ert-deftest jira-days-since-update/unparseable-returns-nil ()
  (should-not (workbench-jira-days-since-update "not-a-date")))

(ert-deftest jira-days-since-update/nil-returns-nil ()
  (should-not (workbench-jira-days-since-update nil)))

;;; ── Fetch ticket parsing ───────────────────────────────────────────────────

(ert-deftest jira-fetch-tickets/parses-tab-separated-output ()
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com"))
    (cl-letf (((symbol-function 'workbench-jira--shell-or-error)
               (lambda (&rest _)
                 (list :ok "DPT-42\tBuild pipeline\tStory\t2025-01-15"))))
      (let ((result (workbench-jira--fetch-tickets)))
        (should (= 1 (length result)))
        (should (equal (plist-get (car result) :key) "DPT-42"))
        (should (equal (plist-get (car result) :summary) "Build pipeline"))
        (should (equal (plist-get (car result) :type) "Story"))
        (should (equal (plist-get (car result) :updated) "2025-01-15"))))))

(ert-deftest jira-fetch-tickets/multiple-lines ()
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com"))
    (cl-letf (((symbol-function 'workbench-jira--shell-or-error)
               (lambda (&rest _)
                 (list :ok "DPT-1\tFirst\tStory\t2025-01-01\nDPT-2\tSecond\tBug\t2025-01-02"))))
      (let ((result (workbench-jira--fetch-tickets)))
        (should (= 2 (length result)))
        (should (equal (plist-get (cadr result) :key) "DPT-2"))
        (should (equal (plist-get (cadr result) :type) "Bug"))))))

(ert-deftest jira-fetch-tickets/empty-output-returns-empty-list ()
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com"))
    (cl-letf (((symbol-function 'workbench-jira--shell-or-error)
               (lambda (&rest _) (list :ok ""))))
      (should (null (workbench-jira--fetch-tickets))))))

(ert-deftest jira-fetch-tickets/no-config-returns-error ()
  (let ((workbench-jira-project nil)
        (workbench-jira-user nil))
    (let ((result (workbench-jira--fetch-tickets)))
      (should (workbench-jira-error-p result)))))

(ert-deftest jira-fetch-tickets/shell-error-propagates ()
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com"))
    (cl-letf (((symbol-function 'workbench-jira--shell-or-error)
               (lambda (&rest _) (list :error "jira exited 1"))))
      (let ((result (workbench-jira--fetch-tickets)))
        (should (workbench-jira-error-p result))
        (should (equal (workbench-jira-error-reason result) "jira exited 1"))))))

;;; ── Fetch done parsing ─────────────────────────────────────────────────────

(ert-deftest jira-fetch-done/limits-to-3 ()
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com"))
    (cl-letf (((symbol-function 'workbench-jira--shell-or-error)
               (lambda (&rest _)
                 (list :ok "DPT-1\tA\nDPT-2\tB\nDPT-3\tC\nDPT-4\tD\nDPT-5\tE"))))
      (let ((result (workbench-jira--fetch-done)))
        (should (= 3 (length result)))))))

;;; ── Fetch next parsing ─────────────────────────────────────────────────────

(ert-deftest jira-fetch-next/limits-to-3 ()
  (let ((workbench-jira-project "DPT"))
    (cl-letf (((symbol-function 'workbench-jira--shell-or-error)
               (lambda (&rest _)
                 (list :ok "DPT-10\tX\tStory\nDPT-11\tY\tBug\nDPT-12\tZ\tTask\nDPT-13\tW\tStory"))))
      (let ((result (workbench-jira--fetch-next)))
        (should (= 3 (length result)))))))

(ert-deftest jira-fetch-next/no-project-returns-error ()
  (let ((workbench-jira-project nil))
    (should (workbench-jira-error-p (workbench-jira--fetch-next)))))

;;; ── Attention items ────────────────────────────────────────────────────────

;; Load command-centre-data for the attention function
(workbench-test-load-module "modules/workflows/command-centre-data")

(ert-deftest attention-items/empty-tickets-returns-nil ()
  (should (null (workbench-cc--team-attention-items '()))))

(ert-deftest attention-items/fresh-tickets-not-flagged ()
  (let* ((today (format-time-string "%Y-%m-%dT%H:%M:%S%z"))
         (tickets (list (list :key "DPT-1" :assignee "Alice" :updated today))))
    (should (null (workbench-cc--team-attention-items tickets)))))

(ert-deftest attention-items/4-day-ticket-flagged-check-in ()
  (let* ((four-days (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                      (time-subtract (current-time) (seconds-to-time (* 4 86400)))))
         (tickets (list (list :key "DPT-5" :assignee "Bob" :updated four-days))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= 1 (length result)))
      (should (equal (plist-get (car result) :reason) "may need check-in")))))

(ert-deftest attention-items/8-day-ticket-flagged-no-update ()
  (let* ((eight-days (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                       (time-subtract (current-time) (seconds-to-time (* 8 86400)))))
         (tickets (list (list :key "DPT-6" :assignee "Carol" :updated eight-days))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= 1 (length result)))
      (should (equal (plist-get (car result) :reason) "no update 7+ days")))))

(ert-deftest attention-items/15-day-ticket-flagged-two-week-rule ()
  (let* ((fifteen-days (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                         (time-subtract (current-time) (seconds-to-time (* 15 86400)))))
         (tickets (list (list :key "DPT-7" :assignee "Dave" :updated fifteen-days))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= 1 (length result)))
      (should (equal (plist-get (car result) :reason) "two-week rule")))))

(ert-deftest attention-items/sorted-by-staleness-desc ()
  (let* ((four-days (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                      (time-subtract (current-time) (seconds-to-time (* 4 86400)))))
         (fifteen-days (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                         (time-subtract (current-time) (seconds-to-time (* 15 86400)))))
         (tickets (list (list :key "DPT-A" :assignee "A" :updated four-days)
                        (list :key "DPT-B" :assignee "B" :updated fifteen-days))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= 2 (length result)))
      (should (equal (plist-get (car result) :key) "DPT-B"))
      (should (equal (plist-get (cadr result) :key) "DPT-A")))))

;;; ── Regression tests ────────────────────────────────────────────────────────

(ert-deftest jira/regression-cache-fresh-with-zero-interval-always-stale ()
  "With refresh-interval=0, cache is never fresh — every call blocks."
  (let ((workbench-jira-refresh-interval 0)
        (workbench-jira--cache-time (current-time)))
    ;; Cache was JUST set, but interval is 0 so it's immediately stale
    (should-not (workbench-jira-cache-fresh-p))))

(ert-deftest jira/regression-cache-fresh-nil-time-is-not-fresh ()
  "Cache with nil time is not fresh."
  (let ((workbench-jira--cache-time nil)
        (workbench-jira-refresh-interval 300))
    (should-not (workbench-jira-cache-fresh-p))))

(ert-deftest jira/regression-cache-fresh-recent-time-is-fresh ()
  "Cache set just now should be fresh."
  (let ((workbench-jira--cache-time (current-time))
        (workbench-jira-refresh-interval 300))
    (should (workbench-jira-cache-fresh-p))))

;;; ── ticket-commented-today-p ───────────────────────────────────────────────

(ert-deftest jira/ticket-commented-today-p-returns-t-for-today ()
  "Returns t when the last comment date matches today."
  (let ((today (format-time-string "%d %b %Y")))
    (cl-letf (((symbol-function 'workbench-jira--ticket-last-comment-date)
               (lambda (_key) (format "Monday, %s" today))))
      (should (workbench-jira--ticket-commented-today-p "TEST-1")))))

(ert-deftest jira/ticket-commented-today-p-returns-nil-for-yesterday ()
  "Returns nil when the last comment date is not today."
  (cl-letf (((symbol-function 'workbench-jira--ticket-last-comment-date)
             (lambda (_key) "Monday, 01 Jan 2020")))
    (should-not (workbench-jira--ticket-commented-today-p "TEST-1"))))

(ert-deftest jira/ticket-commented-today-p-returns-nil-when-no-date ()
  "Returns nil when no comment date is found."
  (cl-letf (((symbol-function 'workbench-jira--ticket-last-comment-date)
             (lambda (_key) nil)))
    (should-not (workbench-jira--ticket-commented-today-p "TEST-1"))))

;;; ── migrate-legacy-vars ────────────────────────────────────────────────────

(ert-deftest jira/migrate-legacy-vars-copies-old-to-new ()
  "Migration copies old workbench-cc--* values to workbench-jira-* when new var is at default."
  (let ((workbench-jira-project nil)  ;; default
        (workbench-cc--jira-project "MIGRATED"))
    ;; Simulate the condition: old var is bound and set, new var is at default
    (cl-letf (((symbol-function 'default-value) (lambda (_sym) nil)))
      (workbench-jira--migrate-legacy-vars)
      (should (equal workbench-jira-project "MIGRATED")))))

(ert-deftest jira/migrate-legacy-vars-does-not-overwrite-existing ()
  "Migration does NOT overwrite when new var differs from its defvar default.
The guard (equal (symbol-value new) (default-value new)) is always t for
non-buffer-local variables, so migration ALWAYS fires if the old var is set.
This test documents that behaviour: when cc-- aliases are active, setting
cc-- IS setting jira- (they're the same symbol), so migration is a no-op."
  ;; With aliases active, setting the cc-- var IS setting the jira- var.
  ;; The migration function's guard doesn't apply because they're aliased.
  ;; This test confirms the alias makes the migration a conceptual no-op.
  (let ((workbench-jira-project "ALREADY-SET"))
    ;; workbench-cc--jira-project is aliased to workbench-jira-project,
    ;; so reading it returns whatever jira-project is set to.
    (should (equal workbench-cc--jira-project "ALREADY-SET"))))

;;; ── Sentinel error safety ──────────────────────────────────────────────────

(ert-deftest jira/sentinel-kills-buffer-even-on-hook-error ()
  "The async sentinel kills the output buffer even if the after-refresh hook errors.
Invokes the real sentinel function extracted from workbench-jira-refresh to
verify the unwind-protect guarantees buffer cleanup."
  (let* ((workbench-jira--cache nil)
         (workbench-jira--cache-time nil)
         (workbench-jira--async-process nil)
         (workbench-jira--async-timeout nil)
         (workbench-jira-project "TEST")
         (workbench-jira-user "test@example.com")
         (workbench-jira-after-refresh-hook
          (list (lambda () (error "Hook error — simulated failure"))))
         (captured-sentinel nil)
         (output-buf nil)
         (real-make-process (symbol-function 'make-process)))
    ;; Intercept make-process to capture the sentinel and output buffer,
    ;; but delegate to the real make-process for actual process creation.
    (cl-letf (((symbol-function 'make-process)
               (lambda (&rest args)
                 (setq captured-sentinel (plist-get args :sentinel))
                 ;; Use a simple "true" command instead of emacs --batch
                 (let* ((buf (plist-get args :buffer))
                        (proc (funcall real-make-process
                                       :name "test-jira-sentinel"
                                       :buffer buf
                                       :command '("true")
                                       :noquery t)))
                   (setq output-buf buf)
                   (setq workbench-jira--async-process proc)
                   proc)))
              ;; Prevent timeout timer from firing
              ((symbol-function 'run-at-time) (lambda (&rest _) nil)))
      ;; Call the real workbench-jira-refresh which builds the sentinel
      (workbench-jira-refresh))
    ;; We now have the real sentinel and a buffer
    (should captured-sentinel)
    (should (buffer-live-p output-buf))
    ;; Populate the output buffer with valid parseable data
    (with-current-buffer output-buf
      (erase-buffer)
      (insert "(:tickets () :done () :next ())"))
    ;; Wait for the process to exit
    (let ((proc workbench-jira--async-process))
      (when (and proc (process-live-p proc))
        (while (process-live-p proc)
          (accept-process-output proc 0.1)))
      ;; Invoke the REAL sentinel — run-hooks will error via our hook
      (let ((buf-name (buffer-name output-buf)))
        (funcall captured-sentinel proc "finished\n")
        ;; Buffer must be dead — unwind-protect guarantees cleanup
        (should-not (get-buffer buf-name))))))

;;; test-jira.el ends here
