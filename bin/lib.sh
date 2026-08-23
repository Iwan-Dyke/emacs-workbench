#!/usr/bin/env bash
# lib.sh — shared utilities for emacs-workbench scripts.
# Source this file; do not execute directly.

fail() {
    printf "fail %s\n" "$1"
    status=1
}

ok() {
    printf "ok  %s\n" "$1"
}

warn() {
    printf "warn %s\n" "$1"
}

run() {
    local description="$1"
    local arg
    shift
    printf "+ %s" "$description"
    for arg in "$@"; do
        printf " %s" "$arg"
    done
    printf "\n"
    "$@"
}

try_run() {
    if run "$@"; then
        return 0
    fi
    warn "$1 failed"
    return 0
}

must_run() {
    if run "$@"; then
        return 0
    fi
    fail "$1 failed"
    return 1
}

have_command() {
    command -v "$1" >/dev/null 2>&1
}
