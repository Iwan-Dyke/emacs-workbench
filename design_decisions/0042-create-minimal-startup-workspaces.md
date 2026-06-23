# 0042. Create Minimal Startup Workspaces

Date: 2026-06-23
Status: Accepted

## Context

The first-pass coding workflow starts from the Doom dashboard, then uses
Dirvish/Dired to browse to a project directory before opening that directory as
a coding workspace.

ADR 0038 deferred full automatic workspace setup because pre-creating code,
notes, git, and AI workspaces could become surprising before the workflows are
stable.

However, the current workflow now has two stable startup contexts:

```text
dashboard
files
```

Those are not full project workflows. They are lightweight entry points for
starting the day and browsing to work.

## Decision

Create two minimal startup workspaces:

```text
dashboard
files
```

The dashboard workspace should hold the Doom dashboard or future customized
workbench dashboard.

The files workspace should open Dirvish/Dired and act as the visual project
browsing surface.

Do not automatically create code, notes, git, or AI workspaces yet. Project
coding workspaces should still be created explicitly from a selected directory
or command.

## Consequences

The workbench starts closer to the user's familiar dashboard-to-file-browser
workflow without committing to full session restore or a large default workspace
set.

The files workspace becomes the bridge between visual browsing and explicit
project coding workspaces.

The broader automatic workspace setup remains deferred until the coding,
knowledge, Git, and AI workflows are more concrete.
