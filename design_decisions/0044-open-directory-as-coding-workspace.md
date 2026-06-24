# 0044. Open a Directory as a Coding Workspace with SPC p o

Date: 2026-06-24
Status: Accepted

## Context

ADR 0041 sets the dashboard-to-Dirvish project flow and requires that opening a
directory as a coding workspace be an explicit command or keybinding, not an
override of Dirvish's Enter behavior.

ADR 0037 uses Doom workspaces as tmux-like tabs. The coding layout (ADR 0014,
amended by ADR 0043) describes the panes but not how a workspace is created from
the browser.

## Decision

Bind `SPC p o` to open the directory selected in Dirvish as a new Doom workspace
named after that directory.

- `RET` in Dirvish keeps its normal file-manager meaning (enter directory, open
  file), per ADR 0041.
- The Treemacs tree roots at exactly the opened directory (see ADR 0043),
  regardless of VCS status, so arbitrary directories can be opened as projects.

Creating the workspace is step-by-step, not a single layout builder:

- `SPC p o` creates the workspace and lands on a placeholder center buffer (see
  ADR 0045).
- The user pulls in the Treemacs tree (`SPC e`) and the project AI pane on
  demand.

A single command that builds or restores the full `Treemacs | Code | AI` layout
at once — the original intent of ADR 0014 — is deferred until the step-by-step
pieces are stable.

## Consequences

Browsing stays fluid; promoting a directory to a project is a deliberate,
separate action.

`SPC p o` is predictable: it always means "make a workspace for this directory."

The richer one-shot or layout-restoring command remains future work without
blocking the first-pass workflow.

Projects are not limited to Git repositories.
