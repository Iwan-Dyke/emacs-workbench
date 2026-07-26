;;; test/unit/test-org.el --- Unit tests for workflows/org.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Stub org-roam so after! block doesn't fail
(provide 'org-roam)
(unless (boundp 'org-roam-directory)
  (defvar org-roam-directory nil))
(unless (boundp 'org-roam-db-location)
  (defvar org-roam-db-location nil))
(unless (fboundp 'org-roam-db-sync)
  (defun org-roam-db-sync () nil))

;; Stub the jira helpers that org.el uses
(unless (fboundp 'workbench-jira-error-p)
  (defun workbench-jira-error-p (result)
    (and (consp result) (eq (car result) :error))))
(unless (fboundp 'workbench-jira-ensure-cache)
  (defun workbench-jira-ensure-cache () nil))
(unless (fboundp 'workbench-jira-cache-tickets)
  (defun workbench-jira-cache-tickets () nil))
(unless (fboundp 'workbench-jira-days-since-update)
  (defun workbench-jira-days-since-update (_s) nil))
(unless (boundp 'workbench-jira-after-refresh-hook)
  (defvar workbench-jira-after-refresh-hook nil))

;; Load the module under test — use a temp org-directory
(workbench-test-load-module "modules/workflows/org")

;;; ── workbench-org--format-ticket ───────────────────────────────────────────

(ert-deftest org-format-ticket/produces-correct-heading ()
  (let ((ticket '(:key "DPT-42" :summary "Fix the build" :type "Bug" :updated "2025-07-01")))
    (let ((result (workbench-org--format-ticket ticket)))
      (should (string-prefix-p "* TODO DPT-42 Fix the build\n" result))
      (should (string-match-p ":ID: DPT-42" result))
      (should (string-match-p ":TYPE: WorkItem" result))
      (should (string-match-p ":ISSUE_TYPE: Bug" result))
      (should (string-match-p ":STATUS: In Progress" result))
      (should (string-match-p ":UPDATED: 2025-07-01" result)))))

(ert-deftest org-format-ticket/handles-missing-optional-fields ()
  "When :type and :updated are absent, defaults apply."
  (let ((ticket '(:key "XY-1" :summary "Minimal ticket")))
    (let ((result (workbench-org--format-ticket ticket)))
      (should (string-prefix-p "* TODO XY-1 Minimal ticket\n" result))
      (should (string-match-p ":ISSUE_TYPE: Story" result))
      (should (string-match-p ":UPDATED: \n" result)))))

;;; ── workbench-org--adr-title ───────────────────────────────────────────────

(ert-deftest org-adr-title/extracts-heading-from-markdown ()
  (workbench-test-with-temp-file f "# ADR 0001 — Use Doom Emacs\n\nSome content.\n"
    (should (equal (workbench-org--adr-title f) "ADR 0001 — Use Doom Emacs"))))

(ert-deftest org-adr-title/falls-back-to-filename ()
  (workbench-test-with-temp-file f "No heading here, just prose.\nMore lines.\n"
    ;; temp files have random names, so just verify it returns something non-nil
    ;; that is the filename without extension
    (let ((result (workbench-org--adr-title f)))
      (should result)
      (should (equal result (file-name-sans-extension (file-name-nondirectory f)))))))

(ert-deftest org-adr-title/handles-h2-not-h1 ()
  "Only # headings count, not ## sub-headings."
  (workbench-test-with-temp-file f "## Sub heading only\n\nContent.\n"
    (let ((result (workbench-org--adr-title f)))
      ;; Should fall back to filename since ## doesn't match ^#\\s-+
      ;; Actually ^#\\s-+ will match ## too in Emacs regex (\\s- is whitespace)
      ;; Let's check the regex: ^#\\s-+\\(.+\\) — this matches "# " but also "## "
      ;; because ^# matches first # then \\s-+ matches "# " or " "
      ;; Wait, "## Sub heading" — ^# matches "#", \\s-+ needs whitespace but next char is "#"
      ;; So ## won't match. Good — fallback to filename.
      (should (equal result (file-name-sans-extension (file-name-nondirectory f)))))))

;;; ── workbench-org--adr-node-id ─────────────────────────────────────────────

(ert-deftest org-adr-node-id/combines-repo-and-filename ()
  (should (equal (workbench-org--adr-node-id "my-repo" "0001-use-doom.md")
                 "my-repo/0001-use-doom")))

(ert-deftest org-adr-node-id/handles-nested-extension ()
  (should (equal (workbench-org--adr-node-id "project" "0042-ci.pipeline.md")
                 "project/0042-ci.pipeline")))

;;; ── workbench-org--write-jira-file ─────────────────────────────────────────

(ert-deftest org-write-jira-file/writes-correct-content ()
  (workbench-test-with-temp-dir dir
    (let ((org-directory dir)
          (workbench-org--jira-file nil))
      (setq workbench-org--jira-file (expand-file-name "jira.org" dir))
      (let ((tickets '((:key "DPT-1" :summary "First" :type "Story" :updated "2025-07-01")
                       (:key "DPT-2" :summary "Second" :type "Bug" :updated "2025-07-02"))))
        (workbench-org--write-jira-file tickets)
        (let ((content (with-temp-buffer
                         (insert-file-contents (expand-file-name "jira.org" dir))
                         (buffer-string))))
          (should (string-match-p "#\\+title: Jira" content))
          (should (string-match-p "In Progress" content))
          (should (string-match-p "#\\+filetags: :jira:generated:" content))
          (should (string-match-p "\\* TODO DPT-1 First" content))
          (should (string-match-p "\\* TODO DPT-2 Second" content))
          (should (string-match-p ":ISSUE_TYPE: Bug" content)))))))

(ert-deftest org-write-jira-file/handles-empty-ticket-list ()
  (workbench-test-with-temp-dir dir
    (let ((org-directory dir)
          (workbench-org--jira-file nil))
      (setq workbench-org--jira-file (expand-file-name "jira.org" dir))
      (workbench-org--write-jira-file nil)
      (let ((content (with-temp-buffer
                       (insert-file-contents (expand-file-name "jira.org" dir))
                       (buffer-string))))
        (should (string-match-p "No tickets loaded\\." content))
        (should-not (string-match-p "\\* TODO" content))))))

(ert-deftest org-write-jira-file/handles-error-ticket-list ()
  "Error plist does NOT overwrite jira.org — preserves existing content."
  (workbench-test-with-temp-dir dir
    (let ((org-directory dir)
          (workbench-org--jira-file nil))
      (setq workbench-org--jira-file (expand-file-name "jira.org" dir))
      ;; Write valid content first
      (workbench-org--write-jira-file '((:key "DPT-1" :summary "Real ticket" :type "Story" :updated "2025-07-01")))
      ;; Now attempt write with error — should NOT overwrite
      (workbench-org--write-jira-file '(:error "jira CLI not found"))
      (let ((content (with-temp-buffer
                       (insert-file-contents (expand-file-name "jira.org" dir))
                       (buffer-string))))
        ;; Original content preserved
        (should (string-match-p "Real ticket" content))
        ;; Error message NOT written to file
        (should-not (string-match-p "No tickets loaded" content))))))
;;; ── Stale skip function ────────────────────────────────────────────────────

(ert-deftest org/stale-skip-skips-recent ()
  "Entries updated within 14 days are skipped."
  (let ((recent (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                  (time-subtract (current-time) (days-to-time 3)))))
    (with-temp-buffer
      (org-mode)
      (insert "* TODO X-1 Test\n:PROPERTIES:\n:UPDATED: " recent "\n:END:\n")
      (goto-char (point-min))
      (should (workbench-org--stale-skip)))))

(ert-deftest org/stale-skip-shows-old ()
  "Entries updated >14 days ago are shown."
  (let ((old (format-time-string "%Y-%m-%dT%H:%M:%S%z"
               (time-subtract (current-time) (days-to-time 20)))))
    (with-temp-buffer
      (org-mode)
      (insert "* TODO X-2 Stale\n:PROPERTIES:\n:UPDATED: " old "\n:END:\n")
      (goto-char (point-min))
      (should-not (workbench-org--stale-skip)))))

(ert-deftest org/stale-skip-skips-no-updated ()
  "Entries without UPDATED property are skipped."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO X-3 No date\n:PROPERTIES:\n:END:\n")
    (goto-char (point-min))
    (should (workbench-org--stale-skip))))

(ert-deftest org/stale-skip-skips-unparseable ()
  "Entries with unparseable UPDATED are skipped."
  (with-temp-buffer
    (org-mode)
    (insert "* TODO X-4 Relative\n:PROPERTIES:\n:UPDATED: 2 hours ago\n:END:\n")
    (goto-char (point-min))
    (should (workbench-org--stale-skip))))

(ert-deftest org/weeknote-path-format ()
  "Weeknote path uses weeknotes/YYYY-WNN.org format."
  (let ((week (format-time-string "%Y-W%V")))
    (cl-letf (((symbol-function 'find-file)
               (lambda (path) path)))
      (let ((result (workbench-org/open-weeknote)))
        (should (string-match-p (regexp-quote week) result))
        (should (string-match-p "weeknotes/" result))
        (should (string-suffix-p ".org" result))))))

;;; test-org.el ends here
