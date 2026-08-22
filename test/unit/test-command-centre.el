;;; test/unit/test-command-centre.el --- Tests for command centre logic -*- lexical-binding: t; -*-

(require 'ert)
(require 'cl-lib)
(require 'test-helper)

(workbench-test-load-module "modules/tools/jira.el")
(workbench-test-load-module "modules/workflows/command-centre-data.el")
(workbench-test-load-module "modules/workflows/command-centre-svg.el")

;;; ── Colour math ────────────────────────────────────────────────────────────

(ert-deftest cc-svg/darken-black-stays-black ()
  "Darkening black by any amount stays black."
  (should (equal (workbench-cc--darken "#000000" 0.5) "#000000")))

(ert-deftest cc-svg/darken-white-by-half ()
  "Darkening white by 0.5 gives mid-grey."
  (let ((result (workbench-cc--darken "#ffffff" 0.5)))
    (should (equal result "#808080"))))

(ert-deftest cc-svg/darken-by-zero ()
  "Darkening by 0 returns the same colour."
  (should (equal (workbench-cc--darken "#4fa6ed" 0) "#4fa6ed")))

(ert-deftest cc-svg/darken-by-one ()
  "Darkening by 1 returns black."
  (should (equal (workbench-cc--darken "#4fa6ed" 1) "#000000")))

(ert-deftest cc-svg/darken-nil-returns-fallback ()
  "Darkening nil colour returns fallback."
  (should (equal (workbench-cc--darken nil 0.5) "#333333")))

(ert-deftest cc-svg/lighten-black-by-half ()
  "Lightening black by 0.5 gives mid-grey."
  (let ((result (workbench-cc--lighten "#000000" 0.5)))
    (should (equal result "#808080"))))

(ert-deftest cc-svg/lighten-white-stays-white ()
  "Lightening white by any amount stays white."
  (should (equal (workbench-cc--lighten "#ffffff" 0.5) "#ffffff")))

(ert-deftest cc-svg/lighten-by-zero ()
  "Lightening by 0 returns the same colour."
  (should (equal (workbench-cc--lighten "#4fa6ed" 0) "#4fa6ed")))

(ert-deftest cc-svg/lighten-nil-returns-fallback ()
  "Lightening nil colour returns fallback."
  (should (equal (workbench-cc--lighten nil 0.5) "#444444")))

;;; ── Attention items ────────────────────────────────────────────────────────

(ert-deftest cc-data/attention-items-empty-for-fresh-tickets ()
  "No attention items for tickets updated today."
  (let ((now (format-time-string "%Y-%m-%dT%H:%M:%S%z")))
    (let ((tickets (list (list :key "X-1" :assignee "A" :updated now))))
      (should (null (workbench-cc--team-attention-items tickets))))))

(ert-deftest cc-data/attention-items-flags-stale-14-days ()
  "Tickets stale >14 days get 'two-week rule' reason."
  (let* ((old (format-time-string "%Y-%m-%dT%H:%M:%S%z"
               (time-subtract (current-time) (days-to-time 16))))
         (tickets (list (list :key "X-2" :assignee "B" :updated old))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= (length result) 1))
      (should (equal (plist-get (car result) :reason) "two-week rule")))))

(ert-deftest cc-data/attention-items-flags-7-days ()
  "Tickets stale >7 days get 'no update 7+ days' reason."
  (let* ((old (format-time-string "%Y-%m-%dT%H:%M:%S%z"
               (time-subtract (current-time) (days-to-time 9))))
         (tickets (list (list :key "X-3" :assignee "C" :updated old))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= (length result) 1))
      (should (equal (plist-get (car result) :reason) "no update 7+ days")))))

(ert-deftest cc-data/attention-items-flags-3-days ()
  "Tickets stale >3 days get 'may need check-in' reason."
  (let* ((old (format-time-string "%Y-%m-%dT%H:%M:%S%z"
               (time-subtract (current-time) (days-to-time 5))))
         (tickets (list (list :key "X-4" :assignee "D" :updated old))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= (length result) 1))
      (should (equal (plist-get (car result) :reason) "may need check-in")))))

(ert-deftest cc-data/attention-items-sorted-by-days ()
  "Attention items sorted most stale first."
  (let* ((old-16 (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                   (time-subtract (current-time) (days-to-time 16))))
         (old-5 (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                  (time-subtract (current-time) (days-to-time 5))))
         (tickets (list (list :key "X-A" :assignee "A" :updated old-5)
                        (list :key "X-B" :assignee "B" :updated old-16))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (= (length result) 2))
      (should (equal (plist-get (car result) :key) "X-B")))))

(ert-deftest cc-data/attention-items-skips-nil-days ()
  "Tickets with unparseable dates (nil days) are skipped."
  (let ((tickets (list (list :key "X-5" :assignee "E" :updated "2 hours ago"))))
    (let ((result (workbench-cc--team-attention-items tickets)))
      (should (null result)))))

(ert-deftest cc-data/attention-items-empty-list ()
  "Empty ticket list returns no attention items."
  (should (null (workbench-cc--team-attention-items '()))))

;;; ── Error predicates ───────────────────────────────────────────────────────

(ert-deftest cc-data/error-p-on-error-plist ()
  "error-p returns t for (:error reason) plist."
  (should (workbench-jira-error-p '(:error "fetch failed"))))

(ert-deftest cc-data/error-p-on-normal-list ()
  "error-p returns nil for normal ticket list."
  (should-not (workbench-jira-error-p '((:key "X-1")))))

(ert-deftest cc-data/error-reason-extracts-message ()
  "error-reason returns the reason string."
  (should (equal (workbench-jira-error-reason '(:error "timeout")) "timeout")))

(provide 'test-command-centre)
;;; test-command-centre.el ends here
