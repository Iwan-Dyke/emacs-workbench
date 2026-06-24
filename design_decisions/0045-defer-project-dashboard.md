# 0045. Defer the Project Dashboard

Date: 2026-06-24
Status: Accepted

## Context

When `SPC p o` opens a coding workspace, the center buffer currently shows only
the project name and path.

A richer project dashboard was discussed: identity, git state, recent files,
runnable `just` recipes, and test or lint health — potentially shaped as a
launcher (like the Neovim alpha dashboard) or as a monitor (like the user's
`pulse` project). That is a meaningful feature with its own design axes
(launcher versus monitor, static snapshot versus live refresh) and is not on the
critical path for a working coding workflow.

The project already defers non-essential surfaces (ADRs 0038, 0039, 0040).

## Decision

Keep a minimal placeholder center buffer for now: project name and path in a
read-only buffer. It exists only until the user opens a file, which replaces it.

Defer the rich project dashboard to its own future design and ADR, covering the
launcher-versus-monitor decision and the specific widgets.

## Consequences

The coding workflow can be completed without designing a dashboard.

The placeholder is intentionally thin and will be replaced wholesale, not
extended ad hoc.

The dashboard design is preserved as explicit future work rather than lost.
