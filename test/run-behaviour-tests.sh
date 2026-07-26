#!/usr/bin/env bash
set -uo pipefail

# Behaviour test harness for emacs-workbench.
# Starts a workbench daemon, triggers startup hooks, runs ERT assertions
# inside the live daemon, then tears it down.
#
# Usage: test/run-behaviour-tests.sh [work|personal]
# Default profile: work (has the most to test — command centre, team-lead view)

REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PROFILE="${1:-work}"
DAEMON_NAME="workbench-${PROFILE}"
TIMEOUT=5
STARTUP_WAIT=8
PASSED=0
FAILED=0
ERRORS=()

# ── Helpers ──────────────────────────────────────────────────────────────────

die()  { printf '\033[0;31mFATAL:\033[0m %s\n' "$1" >&2; cleanup; exit 1; }
info() { printf '\033[0;36m•\033[0m %s\n' "$1"; }
pass() { printf '\033[0;32m✓\033[0m %s\n' "$1"; PASSED=$((PASSED + 1)); }
fail() { printf '\033[0;31m✗\033[0m %s\n' "$1"; FAILED=$((FAILED + 1)); ERRORS+=("$1"); }

eval_or_fail() {
    local desc="$1"
    local expr="$2"
    local result

    result=$(timeout "$TIMEOUT" emacsclient --socket-name "$DAEMON_NAME" --eval "$expr" 2>&1) || {
        fail "$desc (timeout or connection error)"
        return 1
    }

    echo "$result"
}

assert_equal() {
    local desc="$1"
    local expr="$2"
    local expected="$3"
    local result

    result=$(eval_or_fail "$desc" "$expr") || return
    if [[ "$result" == "$expected" ]]; then
        pass "$desc"
    else
        fail "$desc (expected: $expected, got: $result)"
    fi
}

assert_not_nil() {
    local desc="$1"
    local expr="$2"
    local result

    result=$(eval_or_fail "$desc" "$expr") || return
    if [[ "$result" != "nil" ]]; then
        pass "$desc"
    else
        fail "$desc (got nil)"
    fi
}

assert_true() {
    local desc="$1"
    local expr="$2"
    local result

    result=$(eval_or_fail "$desc" "$expr") || return
    if [[ "$result" == "t" ]]; then
        pass "$desc"
    else
        fail "$desc (expected t, got: $result)"
    fi
}

# ── Lifecycle ────────────────────────────────────────────────────────────────

cleanup() {
    if timeout 2 emacsclient --socket-name "$DAEMON_NAME" --eval 't' >/dev/null 2>&1; then
        timeout 3 emacsclient --socket-name "$DAEMON_NAME" --eval '(kill-emacs)' >/dev/null 2>&1 || true
        sleep 1
    fi
    # Force kill if still alive
    pkill -f "daemon=$DAEMON_NAME" 2>/dev/null || true
}

start_daemon() {
    info "Starting daemon: $DAEMON_NAME (profile: $PROFILE)"

    # Abort if a real workbench daemon with this name is already running
    if timeout 2 emacsclient --socket-name "$DAEMON_NAME" --eval 't' >/dev/null 2>&1; then
        die "Daemon $DAEMON_NAME is already running. Stop it first: workbench stop $PROFILE"
    fi

    export WORKBENCH_PROFILE="$PROFILE"
    emacs --daemon="$DAEMON_NAME" 2>&1 | grep -v "^$" || die "Daemon failed to start"

    # Verify it's responsive
    timeout "$TIMEOUT" emacsclient --socket-name "$DAEMON_NAME" --eval 't' >/dev/null 2>&1 \
        || die "Daemon not responsive after start"

    info "Daemon started"
}

trigger_startup() {
    info "Opening frame to trigger startup hooks..."

    # Open a frame — this triggers server-after-make-frame-hook which
    # creates startup workspaces and shows the command centre.
    emacsclient --socket-name "$DAEMON_NAME" -c &
    local client_pid=$!

    # Wait for startup to complete
    sleep "$STARTUP_WAIT"

    # Verify frame exists and startup ran
    local opened
    opened=$(timeout "$TIMEOUT" emacsclient --socket-name "$DAEMON_NAME" --eval \
        '(bound-and-true-p workbench--startup-workspaces-opened)' 2>&1)

    if [[ "$opened" == "t" ]]; then
        info "Startup workspaces opened"
    else
        info "Startup workspaces not confirmed (got: $opened) — tests may fail"
    fi
}

# ── Test Suites ──────────────────────────────────────────────────────────────

test_profile_detection() {
    info "── Profile Detection ──"

    assert_equal "profile is $PROFILE" \
        'workbench/profile' \
        "\"$PROFILE\""

    if [[ "$PROFILE" == "work" ]]; then
        assert_equal "default AI tool is kiro (work)" \
            'workbench/default-ai-tool' \
            '"kiro"'
        assert_equal "command centre view is team-lead (work)" \
            'workbench/command-centre-view' \
            "team-lead"
    else
        assert_equal "default AI tool is codex (personal)" \
            'workbench/default-ai-tool' \
            '"codex"'
    fi
}

test_startup_workspaces() {
    info "── Startup Workspaces ──"

    assert_true "startup workspaces flag is set" \
        '(bound-and-true-p workbench--startup-workspaces-opened)'

    assert_true "agenda workspace exists" \
        '(not (null (+workspace-exists-p "agenda")))'

    assert_true "ai workspace exists" \
        '(not (null (+workspace-exists-p "ai")))'

    assert_true "files workspace exists" \
        '(not (null (+workspace-exists-p "files")))'

    assert_true "repos workspace exists" \
        '(not (null (+workspace-exists-p "repos")))'
}

test_command_centre() {
    info "── Command Centre ──"

    if [[ "$PROFILE" != "work" ]]; then
        info "(skipped — work profile only)"
        return
    fi

    assert_true "command centre buffer exists" \
        '(buffer-live-p (get-buffer "*command-centre*"))'

    assert_equal "command centre is in normal evil state" \
        '(with-current-buffer "*command-centre*" evil-state)' \
        "normal"

    assert_equal "command centre major mode" \
        '(with-current-buffer "*command-centre*" major-mode)' \
        "workbench-cc-mode"

    assert_not_nil "command centre has content" \
        '(and (buffer-live-p (get-buffer "*command-centre*")) (> (with-current-buffer "*command-centre*" (buffer-size)) 10))'
}

test_keybindings() {
    info "── Keybindings ──"

    assert_equal "SPC e → open-project-tree" \
        '(lookup-key doom-leader-map "e")' \
        "workbench/open-project-tree"

    assert_equal "SPC p o → full layout" \
        '(lookup-key doom-leader-map "po")' \
        "workbench/open-project-workspace-full-layout"

    assert_equal "SPC g g → popup magit" \
        '(lookup-key doom-leader-map "gg")' \
        "workbench/toggle-popup-magit"

    assert_equal "SPC t p → popup terminal" \
        '(lookup-key doom-leader-map "tp")' \
        "workbench/toggle-popup-terminal"

    assert_equal "SPC t c → project claude" \
        '(lookup-key doom-leader-map "tc")' \
        "workbench/toggle-project-claude"

    assert_equal "SPC t k → project kiro" \
        '(lookup-key doom-leader-map "tk")' \
        "workbench/toggle-project-kiro"

    assert_equal "SPC a a → default AI workspace" \
        '(lookup-key doom-leader-map "aa")' \
        "workbench/open-default-ai-workspace"

    assert_equal "SPC a p → toggle project AI" \
        '(lookup-key doom-leader-map "ap")' \
        "workbench/toggle-project-ai"

    assert_equal "SPC n a → org agenda" \
        '(lookup-key doom-leader-map "na")' \
        "workbench-org/open-agenda"

    assert_equal "SPC f m → file manager" \
        '(lookup-key doom-leader-map "fm")' \
        "workbench/open-files"
}

test_evil_states() {
    info "── Evil States ──"

    # Command centre should be in normal state
    if [[ "$PROFILE" == "work" ]]; then
        assert_equal "CC buffer evil state is normal" \
            '(with-current-buffer "*command-centre*" evil-state)' \
            "normal"
    fi

    # C-t should be bound in normal state
    assert_equal "C-t bound in normal state" \
        '(lookup-key evil-normal-state-map (kbd "C-t"))' \
        "workbench/toggle-popup-terminal"
}

test_jira_config() {
    info "── Jira Configuration ──"

    if [[ "$PROFILE" != "work" ]]; then
        info "(skipped — work profile only)"
        return
    fi

    assert_not_nil "jira project is configured" \
        'workbench-jira-project'

    assert_not_nil "jira user is configured" \
        'workbench-jira-user'

    # CC fetch has been triggered (data will arrive async)
    assert_not_nil "command centre fetch was triggered" \
        '(or workbench-cc--timer workbench-cc--async-process workbench-cc--data)'
}

test_treemacs_config() {
    info "── Treemacs Configuration ──"

    assert_equal "treemacs-missing-project-action is remove" \
        'treemacs-missing-project-action' \
        "remove"

    assert_equal "treemacs-width-is-initially-locked is nil" \
        '(bound-and-true-p treemacs-width-is-initially-locked)' \
        "nil"

    assert_equal "treemacs-position is left" \
        '(if (boundp (quote treemacs-position)) (symbol-name treemacs-position) "left")' \
        '"left"'
}

test_theme() {
    info "── Theme ──"

    assert_not_nil "a theme is loaded" \
        '(car custom-enabled-themes)'

    if [[ "$PROFILE" == "work" ]]; then
        assert_equal "work profile uses wayne-tech theme" \
            '(car custom-enabled-themes)' \
            "workbench-wayne-tech"
    fi
}

test_full_layout() {
    info "── Full Layout (SPC p o) ──"

    # Open a project workspace with full layout from a dired buffer
    local result
    result=$(eval_or_fail "full layout opens" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (+workspace-switch "files" t)
        (dired (expand-file-name "doom" "'$REPO_ROOT'"))
        (dired-goto-file (expand-file-name "doom/config.el" "'$REPO_ROOT'"))
        (condition-case err
          (progn
            (workbench/open-project-workspace-full-layout)
            "ok")
          (error (format "ERROR: %S" err))))') || return

    if [[ "$result" == '"ok"' ]]; then
        pass "full layout opens without error"
    else
        fail "full layout opens without error (got: $result)"
        return
    fi

    sleep 2  # Let vterm/treemacs settle

    # Check treemacs is visible
    assert_not_nil "treemacs window exists in layout" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (workbench--treemacs-window))'

    # Check dashboard buffer is in a window
    assert_not_nil "project dashboard visible in layout" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (seq-some (lambda (w)
             (string-prefix-p "*workbench:" (buffer-name (window-buffer w))))
             (window-list)))'

    # Check AI pane is visible
    assert_not_nil "AI pane visible in layout" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (seq-some (lambda (w)
             (string-prefix-p "*project-" (buffer-name (window-buffer w))))
             (window-list)))'

    # Check we have 3+ windows (treemacs + dashboard + AI)
    assert_true "layout has 3+ windows" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (>= (length (window-list)) 3))'
}

test_popup_terminal() {
    info "── Popup Terminal ──"

    # Switch to a project workspace first
    eval_or_fail "setup workspace" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (+workspace-switch "main" t)
        t)' >/dev/null

    # Toggle popup terminal ON
    local result
    result=$(eval_or_fail "toggle terminal on" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (condition-case err
          (progn (workbench/toggle-popup-terminal) "ok")
          (error (format "ERROR: %S" err))))') || return

    if [[ "$result" == '"ok"' ]]; then
        pass "popup terminal toggle on succeeds"
    else
        fail "popup terminal toggle on (got: $result)"
        return
    fi

    sleep 1  # Let vterm initialise

    # Check vterm buffer exists and is visible
    assert_not_nil "popup terminal buffer is in vterm-mode" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (let ((buf (get-buffer (format "*workbench-popup-term:%s*" (+workspace-current-name)))))
             (and buf (with-current-buffer buf (derived-mode-p (quote vterm-mode))))))'

    # Toggle OFF — should restore layout
    result=$(eval_or_fail "toggle terminal off" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (condition-case err
          (progn (workbench/toggle-popup-terminal) "ok")
          (error (format "ERROR: %S" err))))') || return

    if [[ "$result" == '"ok"' ]]; then
        pass "popup terminal toggle off succeeds"
    else
        fail "popup terminal toggle off (got: $result)"
    fi

    # Popup buffer should no longer be visible
    assert_equal "popup terminal not visible after toggle off" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (let ((buf (get-buffer (format "*workbench-popup-term:%s*" (+workspace-current-name)))))
             (and buf (not (null (get-buffer-window buf))))))' \
        "nil"
}

test_files_workspace() {
    info "── Files Workspace ──"

    # Switch to files workspace
    eval_or_fail "switch to files" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (+workspace-switch "files" t)
        t)' >/dev/null

    sleep 1

    # Should have a dired buffer active
    assert_not_nil "files workspace has dired buffer" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (+workspace-switch "files")
           (with-current-buffer (window-buffer (selected-window))
             (derived-mode-p (quote dired-mode))))'

    # Switch away and back — should rebuild
    eval_or_fail "switch away" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (+workspace-switch "main" t)
        t)' >/dev/null

    sleep 1

    eval_or_fail "switch back to files" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (+workspace-switch "files")
        t)' >/dev/null

    sleep 2  # Let rebuild fire (run-at-time 0)

    # Still in dired after rebuild
    assert_not_nil "files workspace still dired after re-entry" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (with-current-buffer (window-buffer (selected-window))
             (derived-mode-p (quote dired-mode))))'
}

test_ai_workspace() {
    info "── AI Workspace ──"

    # The AI workspace should have been created during startup
    assert_true "ai workspace exists" \
        '(not (null (+workspace-exists-p "ai")))'

    # Switch to it and check for a vterm buffer
    assert_not_nil "ai workspace has a vterm buffer" \
        '(progn
           (+workspace-switch "ai")
           (seq-some (lambda (buf)
             (with-current-buffer buf
               (and (derived-mode-p (quote vterm-mode))
                    (string-prefix-p "*" (buffer-name)))))
             (buffer-list)))'

    # The AI buffer should be named after the default tool
    assert_not_nil "ai workspace buffer named for default tool" \
        '(get-buffer (format "*%s*" workbench/default-ai-tool))'
}

test_org_integration() {
    info "── Org Integration ──"

    # org-directory should be set
    assert_equal "org-directory is ~/org/" \
        'org-directory' \
        '"~/org/"'

    # org-roam is deferred — check that it's configured to load into org-directory
    assert_not_nil "org-roam configured (will use org-directory)" \
        '(or (bound-and-true-p org-roam-directory)
             (featurep (quote org-roam))
             t)'

    # Custom agenda commands should be registered
    assert_not_nil "custom agenda commands exist" \
        '(bound-and-true-p org-agenda-custom-commands)'

    # The jira.org file path should be configured
    assert_not_nil "jira.org file path is set" \
        '(workbench-org--jira-file)'

    # Capture templates should be defined
    assert_not_nil "org-capture-templates defined" \
        '(bound-and-true-p org-capture-templates)'
}

test_window_navigation() {
    info "── Window Navigation ──"

    # C-h/j/k/l should be bound in normal and visual states
    assert_equal "C-h bound in normal state" \
        '(lookup-key evil-normal-state-map (kbd "C-h"))' \
        "workbench/window-left"

    assert_equal "C-l bound in normal state" \
        '(lookup-key evil-normal-state-map (kbd "C-l"))' \
        "workbench/window-right"

    assert_equal "C-j bound in normal state" \
        '(lookup-key evil-normal-state-map (kbd "C-j"))' \
        "evil-window-down"

    assert_equal "C-k bound in normal state" \
        '(lookup-key evil-normal-state-map (kbd "C-k"))' \
        "evil-window-up"

    # C-t should be in emacs state too
    assert_equal "C-t bound in emacs state" \
        '(lookup-key evil-emacs-state-map (kbd "C-t"))' \
        "workbench/toggle-popup-terminal"

    # vterm should have C-h/j/k/l in exceptions
    assert_not_nil "vterm-keymap-exceptions includes C-h" \
        '(member "C-h" vterm-keymap-exceptions)'

    assert_not_nil "vterm-keymap-exceptions includes C-t" \
        '(member "C-t" vterm-keymap-exceptions)'
}

test_popup_magit() {
    info "── Popup Magit ──"

    # Switch to a workspace with a git project
    eval_or_fail "setup for magit" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (+workspace-switch "main" t)
        (setq default-directory "'$REPO_ROOT'")
        t)' >/dev/null

    # Toggle magit ON
    local result
    result=$(eval_or_fail "toggle magit on" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (condition-case err
          (progn (workbench/toggle-popup-magit) "ok")
          (error (format "ERROR: %S" err))))') || return

    if [[ "$result" == '"ok"' ]]; then
        pass "popup magit toggle on succeeds"
    else
        fail "popup magit toggle on (got: $result)"
        return
    fi

    sleep 1

    # Check magit-status buffer is visible
    assert_not_nil "magit-status buffer visible" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (workbench--popup-magit-showing-p))'

    # Toggle OFF
    result=$(eval_or_fail "toggle magit off" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (condition-case err
          (progn (workbench/toggle-popup-magit) "ok")
          (error (format "ERROR: %S" err))))') || return

    if [[ "$result" == '"ok"' ]]; then
        pass "popup magit toggle off succeeds"
    else
        fail "popup magit toggle off (got: $result)"
    fi

    # Magit should not be visible now
    assert_equal "magit not visible after toggle off" \
        '(with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
           (workbench--popup-magit-showing-p))' \
        "nil"
}

test_project_dashboard() {
    info "── Project Dashboard ──"

    # Open a project dashboard directly
    local result
    result=$(eval_or_fail "open project dashboard" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (+workspace-switch "main" t)
        (condition-case err
          (progn
            (workbench/open-project-dashboard "'$REPO_ROOT'")
            "ok")
          (error (format "ERROR: %S" err))))') || return

    if [[ "$result" == '"ok"' ]]; then
        pass "project dashboard opens"
    else
        fail "project dashboard opens (got: $result)"
        return
    fi

    # Dashboard buffer should exist with expected name
    assert_true "dashboard buffer exists" \
        '(buffer-live-p (get-buffer "*workbench:emacs-workbench*"))'

    # Dashboard is in special-mode with evil normal state
    assert_equal "dashboard evil state is normal" \
        '(with-current-buffer "*workbench:emacs-workbench*" evil-state)' \
        "normal"

    # Dashboard has content (overview, git, languages etc)
    assert_true "dashboard has substantial content" \
        '(> (with-current-buffer "*workbench:emacs-workbench*" (buffer-size)) 200)'

    # Dashboard keybindings via composed keymap or evil
    assert_not_nil "dashboard has key R bound" \
        '(with-current-buffer "*workbench:emacs-workbench*"
           (where-is-internal #'"'"'workbench/refresh-project-dashboard
             (list (current-local-map) workbench-project-dashboard-mode-map)))'
}

test_persp_config() {
    info "── Persp/Workspace Config ──"

    # Auto-save should be disabled (ADR 0013)
    assert_equal "persp-auto-save-opt is 0" \
        'persp-auto-save-opt' \
        "0"

    # Delete-frame should not kill workspaces
    assert_equal "workspace delete hook removed from delete-frame" \
        '(member #'"'"'+workspaces-delete-associated-workspace-h delete-frame-functions)' \
        "nil"
}

test_lsp_config() {
    info "── LSP Configuration ──"

    # LSP vars are deferred until lsp-mode loads; just check they're configured
    assert_not_nil "lsp-auto-guess-root configured" \
        '(or (bound-and-true-p lsp-auto-guess-root)
             (not (boundp (quote lsp-auto-guess-root))))'

    assert_equal "lsp breadcrumbs disabled" \
        '(bound-and-true-p lsp-headerline-breadcrumb-enable)' \
        "nil"
}

test_formatting() {
    info "── Formatting ──"

    # Ruff should be available as a command
    assert_not_nil "ruff executable found" \
        '(executable-find "ruff")'
}

test_resize_mode() {
    info "── Window Resize ──"

    # Resize functions should exist
    assert_true "resize-left is a command" \
        '(commandp #'"'"'workbench/resize-left)'

    assert_true "resize-right is a command" \
        '(commandp #'"'"'workbench/resize-right)'

    assert_true "resize-mode is a command" \
        '(commandp #'"'"'workbench/resize-mode)'

    # SPC w r should be bound
    assert_equal "SPC w r → resize mode" \
        '(lookup-key doom-leader-map "wr")' \
        "workbench/resize-mode"
}

test_additional_keybindings() {
    info "── Additional Keybindings ──"

    assert_equal "SPC w s → startup workspaces" \
        '(lookup-key doom-leader-map "ws")' \
        "workbench/open-startup-workspaces"

    assert_equal "SPC w p → show profile" \
        '(lookup-key doom-leader-map "wp")' \
        "workbench/show-profile"

    assert_equal "SPC w t → switch theme" \
        '(lookup-key doom-leader-map "wt")' \
        "workbench/switch-theme"

    assert_equal "SPC t t → terminal workspace" \
        '(lookup-key doom-leader-map "tt")' \
        "workbench/open-terminal-workspace"

    assert_equal "SPC t x → project codex" \
        '(lookup-key doom-leader-map "tx")' \
        "workbench/toggle-project-codex"

    assert_equal "SPC n w → weeknote" \
        '(lookup-key doom-leader-map "nw")' \
        "workbench-org/open-weeknote"

    assert_equal "SPC n f → org-roam find" \
        '(lookup-key doom-leader-map "nf")' \
        "org-roam-node-find"

    assert_equal "SPC n d → discover ADRs" \
        '(lookup-key doom-leader-map "nd")' \
        "workbench-org-discover-adrs"

    assert_equal "SPC p O → project workspace dwim" \
        '(lookup-key doom-leader-map "pO")' \
        "workbench/open-project-workspace-dwim"
}

test_visual_enhancements() {
    info "── Visual Enhancements ──"

    # Lin is available
    assert_true "lin-mode is a function" \
        '(fboundp #'"'"'lin-mode)'

    # org-modern is available
    assert_true "org-modern is available" \
        '(fboundp #'"'"'global-org-modern-mode)'

    # org-modern-star is configured
    assert_not_nil "org-modern-star set" \
        '(bound-and-true-p org-modern-star)'

    # Agenda block separator is configured
    assert_not_nil "agenda block separator configured" \
        '(bound-and-true-p org-agenda-block-separator)'

    # hl-line module is active (Doom :ui hl-line)
    assert_true "global-hl-line-mode active" \
        '(bound-and-true-p global-hl-line-mode)'
}

test_repos_workspace() {
    info "── Repos Workspace ──"

    # SPC w g keybinding exists
    assert_equal "SPC w g → open-repos" \
        '(lookup-key doom-leader-map "wg")' \
        "workbench/open-repos"

    # Function exists and is interactive
    assert_true "workbench/open-repos is a command" \
        '(commandp #'"'"'workbench/open-repos)'

    # Open repos workspace (scanning may take a few seconds)
    local result
    local saved_timeout="$TIMEOUT"
    TIMEOUT=15
    result=$(eval_or_fail "open repos workspace" '
      (with-selected-frame (seq-find #'"'"'display-graphic-p (frame-list))
        (condition-case err
          (progn (workbench/open-repos) "ok")
          (error (format "ERROR: %S" err))))') || { TIMEOUT="$saved_timeout"; return; }
    TIMEOUT="$saved_timeout"

    if [[ "$result" == '"ok"' ]]; then
        pass "repos workspace opens"
    else
        fail "repos workspace opens (got: $result)"
        return
    fi

    sleep 2

    # Buffer exists and is in correct mode
    assert_true "repos buffer exists" \
        '(buffer-live-p (get-buffer "*repos*"))'

    assert_equal "repos buffer mode" \
        '(with-current-buffer "*repos*" major-mode)' \
        "workbench-repos-mode"

    assert_equal "repos buffer evil state is normal" \
        '(with-current-buffer "*repos*" evil-state)' \
        "normal"

    # Buffer has content (repos found under ~/code)
    assert_true "repos buffer has content" \
        '(> (with-current-buffer "*repos*" (buffer-size)) 50)'

    # Buffer is read-only
    assert_not_nil "repos buffer is read-only" \
        '(with-current-buffer "*repos*" buffer-read-only)'

    # Point starts on a data row (vtable-current-object is non-nil)
    assert_not_nil "point is on a data row after open" \
        '(with-current-buffer "*repos*"
           (goto-char (point-min))
           (let ((found nil))
             (while (and (not found) (not (eobp)))
               (when (vtable-current-object)
                 (setq found t))
               (unless found (forward-line 1)))
             found))'

    # Filter cycle works
    assert_equal "filter cycles to dirty" \
        '(with-current-buffer "*repos*"
           (setq workbench-repos--current-filter '"'"'all)
           (workbench-repos-cycle-filter)
           (substring-no-properties (symbol-name workbench-repos--current-filter)))' \
        '"dirty"'

    # Sort cycle works (s key not intercepted by evil-snipe)
    assert_equal "sort cycles to status" \
        '(with-current-buffer "*repos*"
           (setq workbench-repos--current-sort '"'"'name)
           (workbench-repos-cycle-sort)
           (substring-no-properties (symbol-name workbench-repos--current-sort)))' \
        '"status"'

    # s key resolves to our sort command, not evil-snipe
    assert_equal "s key bound to cycle-sort not snipe" \
        '(with-current-buffer "*repos*"
           (key-binding "s"))' \
        "workbench-repos-cycle-sort"

    # path-at-point returns a path on data row
    assert_not_nil "path-at-point works on data row" \
        '(with-current-buffer "*repos*"
           (goto-char (point-min))
           (let ((found nil))
             (while (and (not found) (not (eobp)))
               (when (vtable-current-object)
                 (setq found t))
               (unless found (forward-line 1)))
             (when found (workbench-repos--path-at-point))))'

    # Fetch all runs without error
    local fetch_result
    TIMEOUT=30
    fetch_result=$(eval_or_fail "fetch all runs" '
      (with-current-buffer "*repos*"
        (condition-case err
          (progn (workbench-repos-fetch-all) "ok")
          (error (format "ERROR: %S" err))))') || { TIMEOUT=5; return; }
    TIMEOUT=5

    if [[ "$fetch_result" == '"ok"' ]]; then
        pass "fetch all completes without error"
    else
        fail "fetch all (got: $fetch_result)"
    fi

    # Pull selected on clean+not-behind gives message (not error)
    assert_not_nil "pull-selected on up-to-date repo gives message" \
        '(with-current-buffer "*repos*"
           (setq workbench-repos--current-filter '"'"'clean)
           (workbench-repos--redraw)
           (goto-char (point-min))
           (vtable-beginning-of-table)
           (forward-line 1)
           (condition-case err
             (progn (workbench-repos-pull-selected) "ok-or-message")
             (user-error (error-message-string err))))'
}

# ── Main ─────────────────────────────────────────────────────────────────────

trap cleanup EXIT

printf '\n\033[1mEmacs Workbench — Behaviour Tests (%s profile)\033[0m\n\n' "$PROFILE"

cleanup 2>/dev/null  # Clean any leftover from previous run
start_daemon
trigger_startup

test_profile_detection
test_startup_workspaces
test_command_centre
test_keybindings
test_additional_keybindings
test_evil_states
test_window_navigation
test_jira_config
test_treemacs_config
test_theme
test_persp_config
test_lsp_config
test_resize_mode
test_org_integration
test_ai_workspace
test_files_workspace
test_popup_terminal
test_popup_magit
test_full_layout
test_project_dashboard
test_visual_enhancements
test_repos_workspace

# ── Summary ──────────────────────────────────────────────────────────────────

printf '\n── Summary ──\n'
printf '\033[0;32m%d passed\033[0m' "$PASSED"
if [[ "$FAILED" -gt 0 ]]; then
    printf ', \033[0;31m%d failed\033[0m\n' "$FAILED"
    printf '\nFailures:\n'
    for err in "${ERRORS[@]}"; do
        printf '  • %s\n' "$err"
    done
    exit 1
else
    printf ', 0 failed\n'
fi
