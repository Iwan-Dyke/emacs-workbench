# 0066 — Build repos workspace as multi-repo dashboard

## Status

Accepted

## Context

Working across 18+ repos means constantly switching terminals to run
`git status`, `git fetch`, and `git pull`. The grafft TUI solved this in the
terminal workflow, but the Emacs workbench had no equivalent — you had to leave
Emacs or open a shell.

ADR 0040 deferred this as "multi-repo operations dashboard (later)". The
command centre shows recent repos but only the top 5 by commit date, with no
actions (fetch, pull, filter).

## Decision

Build a dedicated repos workspace (`SPC w g`) that:

1. Scans configured roots (default `~/code/`) for `.git` directories
2. Shows all repos in a vtable with: status pip, name, branch, dirty count,
   ahead/behind, stash, last commit
3. Supports filter (all/dirty/clean/behind/ahead), sort (name/status/dirty),
   and substring search
4. Provides actions: refresh, fetch all, pull selected/all, open as project
   workspace, open magit
5. Opens in its own Doom workspace (like agenda, ai, files)
6. Scans at startup so data is warm on first visit

Implementation uses:
- `repos-data.el` — scanner, status parsing, filter/sort/search, fetch/pull
- `repos.el` — vtable renderer, mode, commands, entry point
- vtable (Emacs 29+ built-in) for proper column alignment and sorting

The scanner stops at `.git` (no nested discovery), skips standard ignore
directories (node_modules, .venv, etc.), and handles symlinks/cycles.

## Consequences

- Repos workspace is part of the startup set (dashboard → agenda → ai →
  files → repos)
- Scanning 18 repos + git status on each takes ~5s — runs once at startup,
  instant thereafter
- vtable gives free column sorting (click headers), resizing ({/}), and
  proper truncation
- `RET` on a repo opens the full project workspace (Treemacs | Dashboard | AI)
- Replaces the need to switch to terminal for grafft
