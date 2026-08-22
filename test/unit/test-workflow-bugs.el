;;; test/unit/test-workflow-bugs.el --- Tests reproducing workflow bugs -*- lexical-binding: t; -*-

;; These tests document and reproduce workflow-level bugs found in the
;; workbench codebase. Tests that prove a bug exists are expected to FAIL
;; (the assertion tests what *should* happen, not what currently happens).
;; Design/documentation tests that describe architectural issues pass.

(require 'test-helper)

;; ── Module stubs and loads ──────────────────────────────────────────────────

;; Stub org-roam before loading org.el
(provide 'org-roam)
(unless (boundp 'org-roam-directory)
  (defvar org-roam-directory nil))
(unless (boundp 'org-roam-db-location)
  (defvar org-roam-db-location nil))
(unless (fboundp 'org-roam-db-sync)
  (defun org-roam-db-sync () nil))

;; Stub variables the command-centre needs
(defvar workbench/command-centre-view 'ic)
(defvar workbench/profile "work")

;; Command-centre timer variable (the full module can't load in batch due to
;; internal load! calls, but we need the variable for Bug 6 documentation test)
(defvar workbench-cc--timer nil "Auto-refresh timer.")
(unless (fboundp 'workbench-cc--maybe-refresh)
  (defun workbench-cc--maybe-refresh (&rest _)
    "Stub — refresh if the command centre buffer is visible."
    nil))

;; Load modules under test
(workbench-test-load-module "modules/tools/files")
(workbench-test-load-module "modules/tools/jira")
(workbench-test-load-module "modules/workflows/org")

;; Terminals module needs workbench--project-root defined (loaded from files)
(workbench-test-load-module "modules/tools/terminals")

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 4: dirvish-layout-toggle called without active session (files.el)
;;;
;;; `workbench/open-files-full-frame` calls `(dirvish-layout-toggle)` guarded
;;; only by `(fboundp 'dirvish-layout-toggle)`. If dirvish-override-dired-mode
;;; hasn't activated yet, there's no Dirvish session and the toggle either
;;; errors or does nothing useful.
;;;
;;; Expected behaviour: dirvish-layout-toggle should NOT be called when there
;;; is no active Dirvish session (dirvish-curr returns nil).
;;; Actual behaviour: it's called unconditionally whenever fboundp is t.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/4-dirvish-layout-toggle-called-without-session ()
  "dirvish-layout-toggle should not be called when no Dirvish session exists.
This test FAILS against current code, proving the bug: the toggle is called
unconditionally when fboundp is t, regardless of whether a session is active."
  (let ((toggle-called nil))
    (cl-letf (((symbol-function 'delete-other-windows) #'ignore)
              ((symbol-function 'dired) #'ignore)
              ((symbol-function 'workbench--project-root) (lambda () "/tmp/"))
              ;; dirvish-layout-toggle is available (fboundp = t)
              ((symbol-function 'dirvish-layout-toggle)
               (lambda () (setq toggle-called t)))
              ;; No active Dirvish session
              ((symbol-function 'dirvish-curr) (lambda () nil)))
      ;; Make dirvish-curr available via fboundp too
      (workbench/open-files-full-frame "/tmp/" nil)
      ;; BUG: toggle IS called even though there's no session.
      ;; Correct behaviour would be to NOT call it when dirvish-curr is nil.
      ;; This assertion tests the CORRECT behaviour — it FAILS proving the bug.
      (should-not toggle-called))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 6: Dual async refresh duplicates Jira CLI calls
;;;
;;; The Jira module (`workbench-jira--timer`) and the command centre module
;;; (`workbench-cc--timer`) both independently refresh Jira data on timers.
;;; The Jira timer calls `workbench-jira--maybe-refresh` which spawns a child
;;; Emacs running `jira issue list`. The command centre timer calls
;;; `workbench-cc--maybe-refresh` which spawns ANOTHER child Emacs that also
;;; runs `jira issue list` (via workbench-cc--async-collect -> collect-all ->
;;; workbench-cc--jira-tickets -> workbench-jira--fetch-tickets).
;;;
;;; This is a design/documentation test — it passes to prove the dual-system
;;; architecture exists.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/6-dual-timers-both-start-with-jira-config ()
  "Both workbench-jira--timer and workbench-cc--timer would start independently.
This documents the design issue: two parallel systems both invoke jira CLI."
  ;; Verify the Jira module's timer-start function exists and would create a timer
  (let ((workbench-jira--timer nil)
        (workbench-jira-refresh-interval 300))
    ;; Mock the refresh to avoid actually spawning processes
    (cl-letf (((symbol-function 'workbench-jira--maybe-refresh) #'ignore))
      (workbench-jira-start-timer)
      ;; Jira module creates its own timer
      (should workbench-jira--timer)
      ;; Clean up
      (cancel-timer workbench-jira--timer)
      (setq workbench-jira--timer nil)))

  ;; Verify the command centre ALSO creates a timer (in workbench-cc-open)
  ;; The CC timer is set via `(run-at-time 300 300 #'workbench-cc--maybe-refresh)`
  ;; in workbench-cc-open. We verify the timer variable and function exist.
  (should (boundp 'workbench-cc--timer))
  (should (fboundp 'workbench-cc--maybe-refresh))

  ;; Document: both timers call functions that ultimately invoke `jira issue list`:
  ;; - workbench-jira--timer -> workbench-jira--maybe-refresh -> workbench-jira-refresh
  ;;   -> spawns child emacs -> workbench-jira--fetch-tickets -> jira issue list
  ;; - workbench-cc--timer -> workbench-cc--maybe-refresh -> workbench-cc-refresh
  ;;   -> workbench-cc--async-collect -> spawns child emacs -> workbench-cc--collect-all
  ;;   -> workbench-cc--jira-tickets -> workbench-jira--fetch-tickets -> jira issue list
  ;;
  ;; Verify that workbench-cc--jira-tickets delegates to workbench-jira--fetch-tickets
  ;; (proving they hit the same Jira CLI command)
  (should (fboundp 'workbench-cc--jira-tickets))
  (should (fboundp 'workbench-jira--fetch-tickets))

  ;; Call workbench-cc--jira-tickets and verify it calls workbench-jira--fetch-tickets
  (let ((jira-fetch-called nil)
        (workbench-jira-project "TEST")
        (workbench-jira-user "user@test.com"))
    (cl-letf (((symbol-function 'workbench-jira--fetch-tickets)
               (lambda () (setq jira-fetch-called t) '())))
      (workbench-cc--jira-tickets)
      (should jira-fetch-called))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 9: Global C-h binding breaks evil insert-state backspace
;;;
;;; keybindings.el has:
;;;   (map! "C-h" #'workbench/window-left ...)
;;;
;;; Without a state prefix (like :nvm), `map!` in Doom binds to the
;;; `general-override-mode-map` which has higher priority than evil state maps.
;;; This means C-h in insert state calls window-left instead of backspace.
;;;
;;; Compare with C-t which correctly uses `:nvm`:
;;;   (map! :nvm "C-t" #'workbench/toggle-popup-terminal)
;;;
;;; This is a design/documentation test that verifies the binding structure.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/9-c-h-binding-not-state-restricted ()
  "C-h binding is now correctly restricted to :nvm states (fix applied).
Verifies the binding uses `:nvm` prefix so insert-state backspace is preserved."
  ;; Read the keybindings source to verify the binding form
  (let* ((keybindings-file (expand-file-name "modules/system/keybindings.el"
                                             doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents keybindings-file)
                    (buffer-string))))
    ;; Verify C-h is now bound WITH :nvm prefix (fix applied)
    (should (string-match-p "(map! :nvm \"C-h\"" content))
    ;; Verify C-t is also correctly state-scoped: (map! :nvm "C-t" ...)
    (should (string-match-p "(map! :nvm \"C-t\"" content))
    ;; Verify the old global binding is gone
    (should-not (string-match-p "(map! \"C-h\"" content))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 11: jira.org written every 5 min even if data unchanged
;;;
;;; `workbench-org/sync-jira` (hooked to `workbench-jira-after-refresh-hook`)
;;; always calls `workbench-org--write-jira-file` regardless of whether the
;;; tickets have changed since the last write. This means the file is rewritten
;;; every 5 minutes (the refresh interval) even when nothing changed.
;;;
;;; Expected: skip the write if content is identical to what's already on disk.
;;; Actual: always writes.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/11-jira-org-written-even-when-unchanged ()
  "jira.org is NOT rewritten when tickets haven't changed (fix applied).
Verifies the content-comparison guard skips redundant writes."
  (workbench-test-with-temp-dir dir
    (let* ((org-directory (file-name-as-directory dir))
           (workbench-org--jira-file nil)  ; reset cached path
           (tickets '((:key "DPT-1" :summary "Test ticket" :type "Story" :updated "2025-07-01"))))
      ;; Use the real workbench-org--write-jira-file (now has content check)
      (cl-letf (((symbol-function 'workbench-jira-cache-tickets)
                 (lambda () tickets)))
        ;; First sync — should write (file doesn't exist yet)
        (workbench-org/sync-jira)
        (let* ((jira-file (workbench-org--jira-file))
               (mtime-1 (file-attribute-modification-time
                         (file-attributes jira-file))))
          ;; Small sleep to ensure mtime would differ if rewritten
          (sleep-for 0.1)
          ;; Second sync with SAME data — should NOT rewrite
          (workbench-org/sync-jira)
          (let ((mtime-2 (file-attribute-modification-time
                          (file-attributes jira-file))))
            ;; FIX VERIFIED: file was NOT rewritten (mtime unchanged)
            (should (equal mtime-1 mtime-2))))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 12: Popup terminal from AI workspace starts in wrong directory
;;;
;;; When in the AI workspace (a global vterm), `workbench--project-root`
;;; returns `default-directory` which is the AI buffer's cwd (likely ~ or /).
;;; The popup terminal starts there instead of a useful project location.
;;;
;;; Expected: popup terminal should start in a meaningful project directory.
;;; Actual: starts in whatever default-directory is (/ or ~).
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/12-popup-terminal-inherits-ai-workspace-directory ()
  "Popup terminal from AI workspace starts in / instead of a project directory.
This test FAILS against current code, proving the bug: the buffer's
default-directory is set to / (the AI workspace's cwd) rather than a
meaningful project path."
  (let ((workbench-test--current-workspace "AI")
        ;; Simulate being in AI workspace where default-directory is /
        (default-directory "/"))
    (cl-letf (((symbol-function 'project-current) (lambda (&rest _) nil)))
      ;; workbench--project-root will return default-directory = "/"
      ;; because project-current returns nil
      (let ((buf (workbench--popup-terminal-buffer)))
        (unwind-protect
            (progn
              ;; BUG PROOF: buffer's default-directory IS "/" (inherited from AI workspace)
              ;; Correct behaviour: should be a project root or code-root, not "/"
              ;; This assertion tests the CORRECT behaviour — it FAILS proving the bug.
              (should-not (equal "/" (buffer-local-value 'default-directory buf))))
          (kill-buffer buf))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 5 (documented limitation): jira.org editing race
;;;
;;; `workbench-org--write-jira-file` uses `with-temp-file` which performs an
;;; atomic write — it writes to a temp file then renames over the target.
;;; This means any user edits to jira.org will be silently overwritten on the
;;; next refresh (every 5 minutes).
;;;
;;; This is a documentation test — it verifies the pattern exists.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/5-jira-org-write-uses-atomic-overwrite ()
  "workbench-org--write-jira-file uses with-temp-file which overwrites user edits.
This documents the limitation: any manual edits to jira.org will be lost."
  ;; Verify the function exists
  (should (fboundp 'workbench-org--write-jira-file))
  ;; Verify it uses with-temp-file by examining the source
  (let* ((org-file (expand-file-name "modules/workflows/org.el" doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents org-file)
                    (buffer-string))))
    ;; The function body contains with-temp-file (atomic write pattern)
    (should (string-match-p "with-temp-file" content))
    ;; And it's within the write-jira-file function
    (should (string-match-p "defun workbench-org--write-jira-file" content)))
  ;; Demonstrate the overwrite behaviour: write a file, modify it, then
  ;; call the write function again — user edits are lost
  (workbench-test-with-temp-dir dir
    (let* ((org-directory (file-name-as-directory dir))
           (workbench-org--jira-file (expand-file-name "jira.org" org-directory))
           (tickets '((:key "DPT-1" :summary "Test" :type "Story" :updated "2025-07-01"))))
      ;; First write
      (workbench-org--write-jira-file tickets)
      (let ((jira-file workbench-org--jira-file))
        ;; Simulate user edit: append a personal note
        (with-temp-buffer
          (insert-file-contents jira-file)
          (goto-char (point-max))
          (insert "\n* My personal note\nThis will be lost.\n")
          (write-region (point-min) (point-max) jira-file))
        ;; Verify note is there
        (should (string-match-p "My personal note"
                                (with-temp-buffer
                                  (insert-file-contents jira-file)
                                  (buffer-string))))
        ;; Next refresh writes again — user edit is gone
        (workbench-org--write-jira-file tickets)
        (should-not (string-match-p "My personal note"
                                    (with-temp-buffer
                                      (insert-file-contents jira-file)
                                      (buffer-string))))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 13: Team-lead CC refresh overwrites Jira cache with nil personal tickets
;;;
;;; When `workbench/command-centre-view` is 'team-lead, the CC async child
;;; calls `workbench-cc--collect-team-lead` which returns :wip (team tickets)
;;; but previously did NOT include :tickets (personal). The CC refresh callback
;;; did `(plist-get data :tickets)` → nil, then set the shared Jira cache to
;;; (:tickets nil ...). The org module then wrote "No tickets loaded." to
;;; jira.org even though you have active personal tickets.
;;;
;;; Fix: `workbench-cc--collect-team-lead` now also fetches personal tickets.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/13-team-lead-collect-includes-personal-tickets ()
  "Team-lead CC collect now includes :tickets for personal ticket cache sync.
Previously it only had :wip (team tickets) and no :tickets key, causing the
shared Jira cache to be set to nil and jira.org to show 'No tickets loaded'."
  (let ((workbench-jira-project "DPT")
        (workbench-jira-user "test@example.com")
        (workbench-jira-team-id "test-uuid")
        (workbench-jira-team-name "Test Team")
        (workbench-jira-status-wip "In Progress")
        (workbench-jira-status-next "Next")
        (workbench-jira-status-done "Done"))
    ;; Mock all Jira fetch functions
    (cl-letf (((symbol-function 'workbench-jira--fetch-tickets)
               (lambda () '((:key "DPT-10" :summary "My personal ticket" :type "Story" :updated "2025-07-01"))))
              ((symbol-function 'workbench-jira--fetch-team-by-status)
               (lambda (_status) '((:key "DPT-99" :summary "Team ticket" :assignee "Someone" :updated "2025-07-01"))))
              ((symbol-function 'workbench-jira--team-ticket-last-comment)
               (lambda (_key) '(:author nil :snippet nil))))
      (let ((result (workbench-cc--collect-team-lead)))
        ;; Should have team data under :wip
        (should (plist-get result :wip))
        ;; AND personal tickets under :tickets (the fix)
        (should (plist-get result :tickets))
        ;; The personal tickets should be YOUR tickets, not the team's
        (should (equal "DPT-10"
                       (plist-get (car (plist-get result :tickets)) :key)))))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 14: C-h and C-l not in vterm-keymap-exceptions (keybindings.el)
;;;
;;; vterm intercepts keys before Emacs keymaps. Keys not in
;;; vterm-keymap-exceptions are sent to the terminal process. C-h and C-l
;;; were NOT in exceptions, so the vterm-mode-map bindings for window
;;; navigation were dead code — vterm swallowed them.
;;;
;;; Fix: Add "C-h" and "C-l" to vterm-keymap-exceptions.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/14-vterm-exceptions-include-window-nav-keys ()
  "C-h and C-l must be in vterm-keymap-exceptions for window nav to work.
Without them, vterm swallows the keys and the vterm-mode-map bindings are dead."
  (let* ((keybindings-file (expand-file-name "modules/system/keybindings.el"
                                             doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents keybindings-file)
                    (buffer-string))))
    ;; Verify C-h and C-l are in the exceptions list
    (should (string-match-p "\"C-h\"" content))
    (should (string-match-p "\"C-l\"" content))
    ;; Verify they're in the same append form as the other exceptions
    (should (string-match-p "append '(\"C-t\" \"C-h\" \"C-j\" \"C-k\" \"C-l\")" content))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 15: SPC t t (new terminal workspace) from AI workspace starts in /
;;;
;;; Same as bug 12 but for `workbench/open-terminal-workspace` instead of the
;;; popup terminal. It used `workbench--project-root` directly.
;;;
;;; Fix: Use `workbench--popup-terminal-sensible-root` (same fallback chain).
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/15-terminal-workspace-uses-sensible-root ()
  "open-terminal-workspace should use sensible-root, not bare project-root.
Prevents starting in / when called from a non-project context (AI workspace)."
  (let* ((terminals-file (expand-file-name "modules/tools/terminals.el"
                                           doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents terminals-file)
                    (buffer-string))))
    ;; The function should call sensible-root, not project-root directly
    (should (string-match-p "workbench--popup-terminal-sensible-root" content))
    ;; Verify it's in the open-terminal-workspace function
    (should (string-match-p
             "defun workbench/open-terminal-workspace[^}]*sensible-root"
             content))))

;;; ════════════════════════════════════════════════════════════════════════════
;;; Bug 16: C-t and C-h/j/k/l not bound in treemacs or emacs evil state
;;;
;;; keybindings.el uses (map! :nvm "C-t" ...) which only covers
;;; normal/visual/motion. Treemacs uses a custom `treemacs' evil state and
;;; some special buffers (command-centre, help) use `emacs' state. C-t and
;;; window navigation keys must work from ANY pane in the workspace.
;;;
;;; Fix: Add (evil-define-key 'treemacs ...) via (after! treemacs) and
;;; (define-key evil-emacs-state-map ...) for all navigation keys.
;;; ════════════════════════════════════════════════════════════════════════════

(ert-deftest workflow-bug/16-ct-bound-in-treemacs-state ()
  "C-t must be bound in treemacs evil state so popup terminal works from Treemacs pane."
  (let* ((keybindings-file (expand-file-name "modules/system/keybindings.el"
                                             doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents keybindings-file)
                    (buffer-string))))
    ;; Verify treemacs-state binding exists for C-t
    (should (string-match-p "evil-define-key 'treemacs treemacs-mode-map" content))
    (should (string-match-p "\"C-t\".*workbench/toggle-popup-terminal" content))))

(ert-deftest workflow-bug/16-window-nav-bound-in-treemacs-state ()
  "C-h/j/k/l must be bound in treemacs state so you can navigate out of Treemacs."
  (let* ((keybindings-file (expand-file-name "modules/system/keybindings.el"
                                             doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents keybindings-file)
                    (buffer-string))))
    ;; All window nav keys present in the treemacs evil-define-key form
    ;; The form spans multiple lines: (evil-define-key 'treemacs treemacs-mode-map
    ;;   (kbd "C-h") ... (kbd "C-l") ...)
    (should (string-match-p
             "evil-define-key 'treemacs treemacs-mode-map"
             content))
    ;; Each key appears after the treemacs-mode-map declaration
    (let ((treemacs-pos (string-match "evil-define-key 'treemacs treemacs-mode-map" content)))
      (should treemacs-pos)
      (let ((rest (substring content treemacs-pos)))
        (should (string-match-p "(kbd \"C-h\")" rest))
        (should (string-match-p "(kbd \"C-j\")" rest))
        (should (string-match-p "(kbd \"C-k\")" rest))
        (should (string-match-p "(kbd \"C-l\")" rest))))))

(ert-deftest workflow-bug/16-ct-bound-in-emacs-state ()
  "C-t must be bound in evil emacs state so popup terminal works from special buffers."
  (let* ((keybindings-file (expand-file-name "modules/system/keybindings.el"
                                             doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents keybindings-file)
                    (buffer-string))))
    ;; Verify emacs-state bindings exist
    (should (string-match-p "evil-emacs-state-map.*\"C-t\"" content))))

(ert-deftest workflow-bug/16-window-nav-bound-in-emacs-state ()
  "C-j/k/l must be bound in evil emacs state for special buffer navigation.
C-h is intentionally omitted to preserve access to the Emacs help system."
  (let* ((keybindings-file (expand-file-name "modules/system/keybindings.el"
                                             doom-user-dir))
         (content (with-temp-buffer
                    (insert-file-contents keybindings-file)
                    (buffer-string))))
    ;; C-j, C-k, C-l bound in emacs state
    (should (string-match-p "evil-emacs-state-map.*\"C-j\"" content))
    (should (string-match-p "evil-emacs-state-map.*\"C-k\"" content))
    (should (string-match-p "evil-emacs-state-map.*\"C-l\"" content))
    ;; C-h intentionally NOT in emacs-state (shadows help system)
    (should-not (string-match-p "evil-emacs-state-map.*\"C-h\"" content))))

(provide 'test-workflow-bugs)
;;; test/unit/test-workflow-bugs.el ends here
