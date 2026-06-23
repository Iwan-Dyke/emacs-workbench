# 0038. Defer Automatic Workspace Setup

Date: 2026-06-23
Status: Accepted

## Context

Doom workspaces provide the tmux-like tab layer for the workbench. The user
expects common workspaces such as code, notes, git, and AI to be available
without recreating them manually every time.

The workbench is still in first-pass implementation. Workspace behavior can
interact with startup, profile daemons, session restoration, buffers, window
layouts, and project-specific commands.

## Decision

Defer automatic workspace creation until the basic workspace module and manual
workflow are proven.

Use Doom's built-in workspace commands first. Later, add an explicit workbench
command or startup hook that creates the default workspace set for a profile.

Initial target workspaces:

```text
code
notes
git
ai
```

Automatic setup should be profile-aware and idempotent: rerunning it should not
create duplicate workspaces or destroy user buffers unexpectedly.

## Consequences

The first workspace implementation stays simple and easier to debug.

The desired end state is recorded before adding custom behavior, so future
layout work has a clear direction.

The user must create or rename workspaces manually until the default workspace
setup command exists.
