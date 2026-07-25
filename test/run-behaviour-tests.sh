#!/usr/bin/env bash
set -euo pipefail

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
}

test_theme() {
    info "── Theme ──"

    assert_not_nil "a theme is loaded" \
        '(car custom-enabled-themes)'
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
test_evil_states
test_jira_config
test_treemacs_config
test_theme

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
