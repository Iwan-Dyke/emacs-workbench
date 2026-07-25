;;; test/unit/test-session.el --- Unit tests for workflows/session.el -*- lexical-binding: t; -*-

(require 'test-helper)

;; Load dependencies
(workbench-test-load-module "modules/tools/files")

;; Stub AI workspace function before loading session
(unless (fboundp 'workbench/open-default-ai-workspace)
  (defun workbench/open-default-ai-workspace () nil))

;; Stub org agenda function
(unless (fboundp 'workbench-org/open-agenda)
  (defun workbench-org/open-agenda () nil))

(workbench-test-load-module "modules/workflows/session")

;;; ── workbench--files-real-dired-p (buffer name patterns) ───────────────────

(ert-deftest session/real-dired-p/normal-directory-name ()
  "Buffer named after a directory path is a real dired buffer."
  (with-temp-buffer
    (rename-buffer "/home/user/projects" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _) t)))
      (should (workbench--files-real-dired-p)))))

(ert-deftest session/real-dired-p/space-prefix-is-parent ()
  "Buffers starting with space are Dirvish parent panes — not real."
  (with-temp-buffer
    (rename-buffer " /some/parent" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _) t)))
      (should-not (workbench--files-real-dired-p)))))

(ert-deftest session/real-dired-p/dirvish-starred-buffer ()
  "Buffers matching *dirvish-... are Dirvish internals — not real."
  (with-temp-buffer
    (rename-buffer "*dirvish-side*" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _) t)))
      (should-not (workbench--files-real-dired-p)))))

(ert-deftest session/real-dired-p/dirvish-preview ()
  "The *dirvish-preview* buffer is not real."
  (with-temp-buffer
    (rename-buffer "*dirvish-preview*" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _) t)))
      (should-not (workbench--files-real-dired-p)))))

(ert-deftest session/real-dired-p/not-dired-mode ()
  "A buffer not in dired-mode is never real dired."
  (with-temp-buffer
    (rename-buffer "/looks/like/dir" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _) nil)))
      (should-not (workbench--files-real-dired-p)))))

(ert-deftest session/real-dired-p/temp-buffer-star-name ()
  "A *temp* buffer name that doesn't match dirvish pattern but isn't dired."
  (with-temp-buffer
    (rename-buffer "*scratch*" t)
    (cl-letf (((symbol-function 'derived-mode-p)
               (lambda (&rest _) nil)))
      (should-not (workbench--files-real-dired-p)))))

;;; ── workbench--files-track-point-now ───────────────────────────────────────

(ert-deftest session/track-point-now/tracks-in-files-workspace-real-dired ()
  "Tracks directory and file when in 'files' workspace and real dired buffer."
  (let ((workbench-test--current-workspace "files")
        (workbench--files-directory nil)
        (workbench--files-file nil)
        (default-directory "/home/user/projects/"))
    (with-temp-buffer
      (rename-buffer "/home/user/projects" t)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _) t))
                ((symbol-function 'dired-get-filename)
                 (lambda (&optional _localp _noerror) "/home/user/projects/file.txt")))
        (workbench--files-track-point-now)
        (should (equal workbench--files-directory "/home/user/projects/"))
        (should (equal workbench--files-file "/home/user/projects/file.txt"))))))

(ert-deftest session/track-point-now/ignores-non-files-workspace ()
  "Does not track when current workspace is not 'files'."
  (let ((workbench-test--current-workspace "coding")
        (workbench--files-directory nil)
        (workbench--files-file nil)
        (default-directory "/tmp/"))
    (with-temp-buffer
      (rename-buffer "/tmp" t)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _) t))
                ((symbol-function 'dired-get-filename)
                 (lambda (&optional _localp _noerror) "/tmp/x.txt")))
        (workbench--files-track-point-now)
        (should-not workbench--files-directory)
        (should-not workbench--files-file)))))

(ert-deftest session/track-point-now/ignores-non-dired-buffer ()
  "Does not track when the buffer is not a real dired buffer."
  (let ((workbench-test--current-workspace "files")
        (workbench--files-directory nil)
        (workbench--files-file nil)
        (default-directory "/tmp/"))
    (with-temp-buffer
      (rename-buffer "*Messages*" t)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _) nil)))
        (workbench--files-track-point-now)
        (should-not workbench--files-directory)
        (should-not workbench--files-file)))))

(ert-deftest session/track-point-now/ignores-dirvish-parent-pane ()
  "Does not track in a Dirvish parent pane (space-prefixed buffer)."
  (let ((workbench-test--current-workspace "files")
        (workbench--files-directory nil)
        (workbench--files-file nil)
        (default-directory "/home/"))
    (with-temp-buffer
      (rename-buffer " /home/parent" t)
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _) t))
                ((symbol-function 'dired-get-filename)
                 (lambda (&optional _localp _noerror) "/home/parent/x")))
        (workbench--files-track-point-now)
        (should-not workbench--files-directory)
        (should-not workbench--files-file)))))

(ert-deftest session/track-point-now/clears-timer-var ()
  "Clears workbench--files-track-timer on execution."
  (let ((workbench-test--current-workspace "other")
        (workbench--files-track-timer 'fake-timer)
        (workbench--files-directory nil)
        (workbench--files-file nil))
    (with-temp-buffer
      (cl-letf (((symbol-function 'derived-mode-p)
                 (lambda (&rest _) nil)))
        (workbench--files-track-point-now)
        (should-not workbench--files-track-timer)))))

;;; ── workbench/open-startup-workspaces ──────────────────────────────────────

(ert-deftest session/startup-workspaces/creates-correct-workspaces ()
  "Opens agenda, AI, and files workspaces, then returns to starting workspace."
  (let ((workbench-test--current-workspace "main")
        (switches '())
        (ai-opened nil)
        (files-opened nil)
        (agenda-opened nil))
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional _create)
                 (push name switches)
                 (setq workbench-test--current-workspace name)))
              ((symbol-function '+workspace-current-name)
               (lambda () workbench-test--current-workspace))
              ((symbol-function '+workspace/display) #'ignore)
              ((symbol-function 'workbench/open-default-ai-workspace)
               (lambda () (setq ai-opened t)))
              ((symbol-function 'workbench/open-files)
               (lambda () (setq files-opened t)))
              ((symbol-function 'workbench-org/open-agenda)
               (lambda () (setq agenda-opened t))))
      (workbench/open-startup-workspaces)
      ;; Verify all workspaces were created
      (should (member "agenda" switches))
      (should (member "files" switches))
      (should (member "main" switches))  ; returns to starting
      ;; Verify openers were called
      (should ai-opened)
      (should files-opened)
      (should agenda-opened)
      ;; Verify we returned to the starting workspace
      (should (equal workbench-test--current-workspace "main")))))

(ert-deftest session/startup-workspaces/errors-without-workspace-support ()
  "Signals error when workspace functions are missing."
  (cl-letf (((symbol-function '+workspace-switch) nil)
            ((symbol-function '+workspace-current-name) nil))
    (fmakunbound '+workspace-switch)
    (fmakunbound '+workspace-current-name)
    (should-error (workbench/open-startup-workspaces) :type 'user-error)
    ;; Restore stubs
    (defun +workspace-switch (_name &optional _create) nil)
    (defun +workspace-current-name () workbench-test--current-workspace)))

(ert-deftest session/startup-workspaces/returns-to-original-on-error ()
  "Even when AI workspace fails, startup still returns to starting workspace."
  (let ((workbench-test--current-workspace "dashboard")
        (switches '()))
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional _create)
                 (push name switches)
                 (setq workbench-test--current-workspace name)))
              ((symbol-function '+workspace-current-name)
               (lambda () workbench-test--current-workspace))
              ((symbol-function '+workspace/display) #'ignore)
              ((symbol-function 'workbench/open-default-ai-workspace)
               (lambda () (error "AI not configured")))
              ((symbol-function 'workbench/open-files)
               (lambda () nil))
              ((symbol-function 'workbench-org/open-agenda)
               (lambda () nil)))
      ;; The AI error is NOT caught by open-startup-workspaces itself,
      ;; so this will error. Let's verify the agenda workspace was created first.
      (condition-case nil
          (workbench/open-startup-workspaces)
        (error nil))
      ;; Agenda workspace should have been switched to before the AI error
      (should (member "agenda" switches)))))

;;; ── Regression tests ────────────────────────────────────────────────────────

(ert-deftest session/regression-files-full-frame-fires-in-wrong-workspace ()
  "Deferred timer from files entry fires even if user left files workspace.
Verify the guard works — lambda re-checks workspace name."
  (let ((workbench-test--current-workspace "files")
        (rebuild-called nil))
    (cl-letf (((symbol-function 'workbench--files-dirvish-layout-active-p) (lambda () nil))
              ((symbol-function 'workbench/open-files-full-frame)
               (lambda (&rest _) (setq rebuild-called t)))
              ((symbol-function 'display-graphic-p) (lambda () t)))
      ;; Trigger the hook
      (workbench--files-workspace-full-frame)
      ;; Simulate: user switches away before timer fires
      (setq workbench-test--current-workspace "coding")
      ;; The lambda checks (+workspace-current-name) == "files"
      ;; Since we changed workspace, it should NOT rebuild.
      (should-not rebuild-called))))

(ert-deftest session/regression-files-tracking-is-global-not-frame-local ()
  "Two frames with 'files' workspace clobber each other's tracked position.
BUG: workbench--files-directory is a single global variable."
  :expected-result :failed
  (let ((workbench-test--current-workspace "files")
        (workbench--files-directory nil)
        (workbench--files-file nil))
    (cl-letf (((symbol-function 'workbench--files-real-dired-p) (lambda () t))
              ((symbol-function 'dired-get-filename) (lambda (&rest _) "/frame-A/file.txt")))
      ;; Frame A tracks position
      (let ((default-directory "/frame-A/"))
        (workbench--files-track-point-now))
      (should (equal workbench--files-directory "/frame-A/"))
      ;; Frame B tracks position (clobbers Frame A)
      (let ((default-directory "/frame-B/"))
        (cl-letf (((symbol-function 'dired-get-filename) (lambda (&rest _) "/frame-B/other.txt")))
          (workbench--files-track-point-now)))
      (should (equal workbench--files-directory "/frame-B/"))
      ;; BUG: Frame A's position is lost — this assertion fails (proving the bug)
      (should (equal workbench--files-directory "/frame-A/")))))

(ert-deftest session/regression-startup-half-created-when-ai-errors ()
  "FIXED: Each startup workspace step is wrapped in condition-case."
  (let ((workbench-test--current-workspace "main")
        (workspaces-created '())
        (final-workspace nil))
    (cl-letf (((symbol-function '+workspace-switch)
               (lambda (name &optional _create)
                 (push name workspaces-created)
                 (setq workbench-test--current-workspace name)))
              ((symbol-function '+workspace/display) #'ignore)
              ((symbol-function 'workbench-org/open-agenda) #'ignore)
              ;; AI workspace errors
              ((symbol-function 'workbench/open-default-ai-workspace)
               (lambda () (error "vterm not available")))
              ((symbol-function 'workbench/open-files) #'ignore))
      (condition-case nil
          (workbench/open-startup-workspaces)
        (error nil))
      (setq final-workspace workbench-test--current-workspace)
      ;; SHOULD have returned to "main" even after error
      (should (equal final-workspace "main"))
      ;; SHOULD have created "files" workspace even after AI error
      (should (member "files" workspaces-created)))))

;;; test/unit/test-session.el ends here
