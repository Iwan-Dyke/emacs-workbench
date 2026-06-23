# 0039. Defer Project AI Controls to Coding Workflow

Date: 2026-06-23
Status: Accepted

## Context

The workbench distinguishes global/session AI from project/layout AI. Global AI
is useful as a broad conversation or session-level terminal. Project AI is
intended to sit beside code in the command-driven coding layout.

Adding separate user-facing commands for every project AI variant early would
create a noisy command surface:

```text
open default AI
open project default AI
open Codex
open project Codex
open Kiro
open project Kiro
open Claude
open project Claude
```

That exposes an implementation distinction before the coding workflow exists.

## Decision

Keep first-pass AI keybindings focused on global/session AI.

Defer project/layout AI controls until the coding workflow is implemented. The
future coding layout command should own project AI behavior and open the
profile's default project AI pane as part of the layout.

The user should not need to choose between global and project AI from the
general AI command group before the workbench has a concrete coding layout.

## Consequences

The current AI command surface stays small and easier to learn.

Project AI remains part of the architecture, but its UX will be designed with
the coding workflow instead of as standalone duplicate commands.

When the coding layout is implemented, it can introduce project AI buffers and
bindings only where they naturally fit.
