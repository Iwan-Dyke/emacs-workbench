# 0013. Start Clean and Defer Session Restore

Date: 2026-06-22
Status: Accepted

## Context

Emacs and Doom can restore previous buffers, workspaces, layouts, recent files,
and cursor positions. This can make Emacs behave more like a persistent tmux
session.

During the first pass, the workbench architecture and config will still be
changing. Full automatic session restoration could restore stale buffers,
cluttered layouts, or terminal state that makes startup harder to understand.

## Decision

Start clean at the Doom dashboard.

Allow lightweight memory such as recent files, project history, and cursor
position restore.

Defer full session, workspace, and layout restoration to a later decision.

## Consequences

Startup remains predictable while the workbench is being developed.

The user can still reopen recent files and projects through Doom/dashboard
commands.

The first pass will not behave like a full tmux session restore. That can be
revisited after the core workflows are stable.
