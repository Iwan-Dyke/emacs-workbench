;;; test/unit/test-core.el --- Unit tests for system/core.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; The profile detection logic lives in a `defvar' initializer, which runs
;; once at load time. To test the logic without reloading, we extract the
;; conditional expression into a helper that mirrors the defvar body.

(defun workbench-test--detect-profile (daemon-value env-value)
  "Reproduce the profile detection logic from core.el.
DAEMON-VALUE is what `daemonp' would return (nil, t, or a string).
ENV-VALUE is what WORKBENCH_PROFILE env var would contain (or nil)."
  (let ((profile (or (let ((name daemon-value))
                       (when (and (stringp name)
                                  (string-prefix-p "workbench-" name))
                         (substring name (length "workbench-"))))
                     env-value
                     "personal")))
    (if (member profile '("personal" "work"))
        profile
      "personal")))

;;; ── Daemon name detection ──────────────────────────────────────────────────

(ert-deftest core/profile/daemon-workbench-personal ()
  "Daemon name 'workbench-personal' yields profile 'personal'."
  (should (equal (workbench-test--detect-profile "workbench-personal" nil)
                 "personal")))

(ert-deftest core/profile/daemon-workbench-work ()
  "Daemon name 'workbench-work' yields profile 'work'."
  (should (equal (workbench-test--detect-profile "workbench-work" nil)
                 "work")))

(ert-deftest core/profile/daemon-unknown-falls-back-to-personal ()
  "Unknown daemon name (workbench-foo) falls back to 'personal'."
  (should (equal (workbench-test--detect-profile "workbench-foo" nil)
                 "personal")))

;;; ── Non-workbench daemon / env var fallback ────────────────────────────────

(ert-deftest core/profile/non-workbench-daemon-uses-env ()
  "Non-workbench daemon name uses WORKBENCH_PROFILE env var."
  (should (equal (workbench-test--detect-profile "server" "work")
                 "work")))

(ert-deftest core/profile/non-workbench-daemon-env-personal ()
  "Non-workbench daemon name with env set to personal."
  (should (equal (workbench-test--detect-profile "server" "personal")
                 "personal")))

(ert-deftest core/profile/non-workbench-daemon-env-unknown ()
  "Non-workbench daemon name with unknown env value falls back to personal."
  (should (equal (workbench-test--detect-profile "server" "staging")
                 "personal")))

;;; ── No daemon, no env var ──────────────────────────────────────────────────

(ert-deftest core/profile/no-daemon-no-env-defaults-personal ()
  "No daemon, no env var → defaults to 'personal'."
  (should (equal (workbench-test--detect-profile nil nil)
                 "personal")))

(ert-deftest core/profile/no-daemon-env-work ()
  "No daemon but env var set to 'work'."
  (should (equal (workbench-test--detect-profile nil "work")
                 "work")))

(ert-deftest core/profile/daemon-t-no-env ()
  "Daemon returns t (non-string) with no env → defaults to personal."
  (should (equal (workbench-test--detect-profile t nil)
                 "personal")))

(provide 'test-core)
;;; test/unit/test-core.el ends here
