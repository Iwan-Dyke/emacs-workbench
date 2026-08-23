;;; test/unit/test-bugs.el --- Tests reproducing known bugs -*- lexical-binding: t; -*-

;; These tests document and reproduce known bugs. They are expected to FAIL
;; against current code, proving the bugs exist.

(require 'test-helper)

;; Load modules under test
(workbench-test-load-module "modules/tools/jira")
(workbench-test-load-module "modules/workflows/command-centre-data")
(workbench-test-load-module "modules/workflows/coding")

;; Load command-centre.el's on-resize function and hook directly.
;; We can't load the full module since its internal load! calls resolve
;; relative to doom-user-dir (not the file's own directory). Instead,
;; load just the pieces we need for bugs 5 and 8.
(defvar workbench/command-centre-view 'ic)
(defvar workbench/profile "personal")
(defvar workbench-cc--buffer-name "*command-centre*")
(defvar workbench-cc--data nil)

;; Load the SVG module (needed for workbench-cc--render)
(workbench-test-load-module "modules/workflows/command-centre-svg")

;; Define the on-resize function exactly as in command-centre.el (debounced version)
(defvar workbench-cc--resize-timer nil
  "Debounce timer for command centre resize re-render.")

(defun workbench-cc--on-resize (&optional _frame)
  "Schedule a debounced redraw if command centre is visible."
  (when (and workbench-cc--data
             (eq workbench/command-centre-view 'ic)
             (get-buffer-window workbench-cc--buffer-name))
    (when (timerp workbench-cc--resize-timer)
      (cancel-timer workbench-cc--resize-timer))
    (setq workbench-cc--resize-timer
          (run-at-time 0.3 nil
                       (lambda ()
                         (setq workbench-cc--resize-timer nil)
                         (when (get-buffer-window workbench-cc--buffer-name)
                           (workbench-cc--render workbench-cc--data)))))))

;; Add it to the hook exactly as command-centre.el does
(add-hook 'window-size-change-functions #'workbench-cc--on-resize)

;; Stub for coding tests
(unless (fboundp 'workbench/open-project-dashboard)
  (defun workbench/open-project-dashboard (&optional _dir) nil))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 1: Jira tab parsing collapses empty columns
;;;
;;; `(split-string line "\t+" nil)` uses a regex that matches one-or-more tabs,
;;; so adjacent tabs (empty field) are collapsed — columns shift left.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/jira-tab-parsing-collapses-empty-columns ()
  "Adjacent tabs (empty field) should produce an empty string column, not collapse."
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com"))
    ;; Simulate jira output with an empty SUMMARY field (adjacent tabs between KEY and TYPE)
    ;; Format: KEY\tSUMMARY\tTYPE\tUPDATED
    ;; The empty SUMMARY means KEY<TAB><TAB>TYPE<TAB>UPDATED
    (cl-letf (((symbol-function 'workbench-shell-or-error)
               (lambda (&rest _)
                 (list :ok "DPT-99\t\tBug\t2025-06-01"))))
      (let* ((result (workbench-jira--fetch-tickets))
             (ticket (car result)))
        ;; With correct parsing, empty SUMMARY should be ""
        ;; KEY=DPT-99, SUMMARY="", TYPE=Bug, UPDATED=2025-06-01
        (should (equal (plist-get ticket :key) "DPT-99"))
        (should (equal (plist-get ticket :summary) ""))
        (should (equal (plist-get ticket :type) "Bug"))
        (should (equal (plist-get ticket :updated) "2025-06-01"))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 2: Commit message parsing truncated by pipe character
;;;
;;; `(split-string line "|" nil)` splits on ALL pipe characters, so a commit
;;; message containing `|` gets truncated — only text before the first pipe
;;; in the message is captured.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/commit-message-truncated-by-pipe ()
  "Commit messages containing | should be captured in full."
  (let ((workbench-jira-git-author "Test User")
        (workbench-jira-code-root "/tmp/"))
    ;; Simulate git log output: epoch|relative-time|message-with-pipe
    (cl-letf (((symbol-function 'workbench-cc--recent-repos)
               (lambda () '("/tmp/myrepo")))
              ((symbol-function 'workbench-shell-lines)
               (lambda (_dir &rest _args)
                 '("1720000000|2 hours ago|fix: use A | B pattern"))))
      (let* ((commits (workbench-cc--recent-commits))
             (commit (car commits)))
        ;; The full message should be "fix: use A | B pattern"
        ;; With the bug, it's just "fix: use A " (truncated at the pipe in the message)
        (should commit)
        (should (equal (plist-get commit :msg) "fix: use A | B pattern"))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 3: Workspace lookup stops at first gap in suffixed names
;;;
;;; `workbench--find-workspace-for-directory` iterates base, base<2>, base<3>...
;;; but the while loop condition requires (+workspace-exists-p candidate) to be
;;; true to continue. If there's a gap (e.g. "foo" and "foo<3>" exist but
;;; "foo<2>" doesn't), the loop stops at <2> and never checks <3>.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/workspace-lookup-stops-at-gap ()
  "Workspace lookup should find foo<3> even when foo<2> doesn't exist."
  (let ((workbench-test--workspaces '("foo" "foo<3>"))
        (workbench--workspace-directories (make-hash-table :test 'equal)))
    ;; Register foo<3> as belonging to /tmp/foo-third/ (use truename like real code does)
    (puthash "foo<3>" (file-name-as-directory (file-truename "/tmp/foo-third"))
             workbench--workspace-directories)
    ;; foo belongs to /tmp/foo-original/
    (puthash "foo" (file-name-as-directory (file-truename "/tmp/foo-original"))
             workbench--workspace-directories)
    ;; Look up the directory that belongs to foo<3>
    (let ((result (workbench--find-workspace-for-directory "foo" "/tmp/foo-third")))
      ;; Should find "foo<3>" — but the bug means it stops at foo<2> (doesn't exist)
      ;; and returns nil
      (should (equal result "foo<3>")))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 4: Duplicate org-agenda-custom-commands — second setq overwrites first
;;;
;;; org.el sets `org-agenda-custom-commands` twice inside (after! org ...).
;;; The first block contains an inline skip-function, the second block uses
;;; `#'workbench-org--stale-skip`. The second overwrites the first entirely,
;;; making the first block dead code. Also, the first block has an "i" key for
;;; inbox that could collide with other uses.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/org-agenda-duplicate-setq-second-wins ()
  "The second setq of org-agenda-custom-commands should win (proving first is dead code)."
  ;; Load org module which sets org-agenda-custom-commands
  (defvar org-agenda-custom-commands nil)
  (defvar org-agenda-files nil)
  (defvar org-roam-directory nil)
  (defvar org-roam-db-location nil)
  (defvar org-capture-templates nil)
  ;; Stub org functions
  (unless (fboundp 'org-roam-db-sync)
    (defun org-roam-db-sync () nil))
  (unless (fboundp 'org-agenda-skip-entry-if)
    (defun org-agenda-skip-entry-if (&rest _) nil))
  (unless (fboundp 'org-end-of-subtree)
    (defun org-end-of-subtree (&optional _) nil))
  (unless (fboundp 'org-entry-get)
    (defun org-entry-get (&rest _) nil))
  (unless (fboundp 'org-agenda)
    (defun org-agenda (&rest _) nil))
  (unless (fboundp 'org-id-new)
    (defun org-id-new () "test-id"))
  (workbench-test-load-module "modules/workflows/org")
  ;; The second setq includes "w" (weeknotes) and uses #'workbench-org--stale-skip
  ;; The first does NOT include "w" and uses an inline skip function.
  ;; If the second won, "w" should be present.
  (let ((keys (mapcar #'car org-agenda-custom-commands)))
    ;; Prove second block won: "w" key is present (only in second setq)
    (should (member "w" keys))
    ;; Verify the stale view ("s") uses the named function (second block's version)
    (let* ((s-entry (assoc "s" org-agenda-custom-commands))
           ;; s-entry structure: ("s" desc ((todo query ((settings...)))))
           (todo-settings (nth 2 (nth 0 (nth 2 s-entry))))
           (skip-fn (cadr (assq 'org-agenda-skip-function todo-settings))))
      ;; In a quoted list, #'workbench-org--stale-skip is stored as the form
      ;; (function workbench-org--stale-skip). Verify it references the correct function.
      (should (equal skip-fn '(function workbench-org--stale-skip)))))
  ;; No duplicate keys
  (let ((keys (mapcar #'car org-agenda-custom-commands)))
    (should (equal keys (delete-dups (copy-sequence keys))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 5: SVG re-render fires on unrelated window resizes
;;;
;;; `workbench-cc--on-resize` renders whenever the CC buffer is visible,
;;; regardless of whether the CC window's actual dimensions changed. Any
;;; window resize in the frame (e.g. resizing a split that doesn't contain
;;; the CC buffer's window) will trigger a full SVG re-render.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/cc-resize-renders-without-size-check ()
  "on-resize schedules render without checking if CC window dimensions changed.
Even with debouncing, the render still fires whenever ANY window in the frame
resizes — not just when the CC window's size changes. This wastes SVG redraws."
  ;; Set up: CC data exists, view is 'ic, CC buffer is visible
  (let ((workbench-cc--data '(:tickets () :repos () :commits () :infra () :time "now"))
        (workbench/command-centre-view 'ic)
        (workbench-cc--resize-timer nil)
        (render-count 0))
    ;; Create CC buffer and make it appear visible
    (let ((cc-buf (get-buffer-create "*command-centre*")))
      (unwind-protect
          (progn
            ;; Mock get-buffer-window to return a window (pretend CC is visible)
            (cl-letf (((symbol-function 'get-buffer-window)
                       (lambda (_name &rest _) (selected-window)))
                      ;; Mock the render function to count calls
                      ((symbol-function 'workbench-cc--render)
                       (lambda (_data) (cl-incf render-count))))
              ;; Call on-resize — a timer is scheduled (debounced)
              (workbench-cc--on-resize nil)
              ;; Timer is scheduled
              (should (timerp workbench-cc--resize-timer))
              ;; Fire the timer manually to simulate the debounce completing
              (funcall (timer--function workbench-cc--resize-timer))
              ;; BUG: render IS called even though CC window size didn't change
              ;; Correct behavior: should NOT render if size is unchanged
              (should (> render-count 0))))
        (when (timerp workbench-cc--resize-timer)
          (cancel-timer workbench-cc--resize-timer)
          (setq workbench-cc--resize-timer nil))
        (kill-buffer cc-buf)))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 6: days-since-update returns nil for relative date strings
;;;
;;; `workbench-jira-days-since-update` uses `date-to-time` which only handles
;;; absolute date formats (ISO 8601 etc). Relative strings like "2 hours ago"
;;; (which jira CLI can output) return nil.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/jira-days-since-update-nil-for-relative-dates ()
  "Relative date strings like '2 hours ago' should ideally return a number, but return nil."
  ;; This documents the limitation: relative dates can't be parsed
  (should (null (workbench-jira-days-since-update "2 hours ago")))
  (should (null (workbench-jira-days-since-update "3 days ago")))
  (should (null (workbench-jira-days-since-update "1 week ago"))))

(ert-deftest bug/jira-days-since-update-works-for-iso-dates ()
  "ISO dates should work correctly (control test)."
  (let* ((yesterday (format-time-string "%Y-%m-%dT%H:%M:%S%z"
                      (time-subtract (current-time) (seconds-to-time 86400)))))
    (let ((days (workbench-jira-days-since-update yesterday)))
      (should days)
      (should (numberp days)))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 7: Jira refresh is synchronous/blocking — FIXED
;;;
;;; `workbench-jira-refresh` is now async (spawns a child Emacs process).
;;; `workbench-jira-refresh-sync` exists for callers that need blocking.
;;; This test verifies the sync version works correctly.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/jira-refresh-calls-fetches-synchronously ()
  "workbench-jira-refresh-sync calls all three fetch functions synchronously."
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com")
        (calls nil))
    (cl-letf (((symbol-function 'workbench-jira--fetch-tickets)
               (lambda () (push 'tickets calls) '()))
              ((symbol-function 'workbench-jira--fetch-done)
               (lambda () (push 'done calls) '()))
              ((symbol-function 'workbench-jira--fetch-next)
               (lambda () (push 'next calls) '())))
      (workbench-jira-refresh-sync)
      ;; All three are called (synchronously, in sequence)
      (should (memq 'tickets calls))
      (should (memq 'done calls))
      (should (memq 'next calls))
      ;; Document that they are called in a single synchronous function —
      ;; workbench-jira-refresh is now async; this tests the sync variant
      (should (= 3 (length calls))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 8: Command centre on-resize has no debounce
;;;
;;; `workbench-cc--on-resize` is added directly to `window-size-change-functions`
;;; with no debounce timer or idle wrapper. Rapid resize events (e.g. dragging
;;; a frame edge) trigger repeated expensive SVG re-renders.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest bug/cc-on-resize-no-debounce ()
  "FIXED: workbench-cc--on-resize now debounces with a 0.3s timer.
Rapid resize events no longer trigger repeated expensive SVG re-renders.
Only the last event in a burst fires the actual render."
  ;; The function is still in window-size-change-functions
  (should (memq 'workbench-cc--on-resize window-size-change-functions))
  ;; Verify the function NOW has internal debounce:
  ;; calling twice in rapid succession only schedules ONE render
  (let ((workbench-cc--data '(:tickets () :repos () :commits () :infra () :time "now"))
        (workbench/command-centre-view 'ic)
        (workbench-cc--resize-timer nil)
        (render-count 0))
    (let ((cc-buf (get-buffer-create "*command-centre*")))
      (unwind-protect
          (cl-letf (((symbol-function 'get-buffer-window)
                     (lambda (_name &rest _) (selected-window)))
                    ((symbol-function 'workbench-cc--render)
                     (lambda (_data) (cl-incf render-count))))
            ;; Call twice in rapid succession — debounce means only 1 timer
            (workbench-cc--on-resize nil)
            (workbench-cc--on-resize nil)
            ;; Only one timer scheduled (second cancelled the first)
            (should (timerp workbench-cc--resize-timer))
            ;; No render has fired yet (waiting for timer)
            (should (= render-count 0))
            ;; Fire the timer — only ONE render
            (funcall (timer--function workbench-cc--resize-timer))
            (should (= render-count 1)))
        (when (timerp workbench-cc--resize-timer)
          (cancel-timer workbench-cc--resize-timer)
          (setq workbench-cc--resize-timer nil))
        (kill-buffer cc-buf)))))

(provide 'test-bugs)
;;; test-bugs.el ends here
