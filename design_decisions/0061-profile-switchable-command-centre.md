# 0061. Profile-switchable Command Centre

Date: 2026-07-01
Status: Accepted

## Context

The command centre (ADR 0058) was built for an IC workflow: my tickets, my
commits, my repos. A temporary move to team lead means the startup view needs
to show team health, not personal progress.

This is a temporary post. When it ends, the IC view should come back without
reworking the config. Both views share the same rendering infrastructure (SVG,
theme-aware, auto-refresh) but show different data and layout.

## Decision

Make the command centre view switchable based on a role setting in the work
profile, defaulting to IC.

### Mechanism

A single variable controls which dashboard renders:

```elisp
(setq workbench/command-centre-view 'team-lead)  ;; or 'ic (default)
```

Set in `doom/profiles/work.el` alongside the existing profile defaults. When
the role changes back, flip the value — no other config changes needed.

### Views

- **IC view** (existing): my tickets, my commits, my repos, infra status.
- **Team lead view** (new, ADR 0063): team board swimlanes, blockers/attention,
  activity feed, infra status (condensed).

Both views share:
- Header bar (greeting, date, profile)
- WIP gauge (scoped differently — personal vs team)
- Infrastructure section (condensed in team lead view)
- Auto-refresh on timer + manual `r`
- Resize on window change
- Theme-aware colours

### Profile file change

```elisp
;; doom/profiles/work.el
(setq workbench/command-centre-view 'team-lead)
```

When returning to senior:

```elisp
(setq workbench/command-centre-view 'ic)  ;; or just remove the line
```

## Consequences

- The command centre render function dispatches on the view variable, calling
  either the existing IC renderer or the new team lead renderer.
- Both renderers live in the same module (`command-centre.el`) since they share
  helpers (SVG primitives, shell calls, theme colours).
- Adding future views (e.g. delivery manager, tech architect) follows the same
  pattern without structural changes.
- No data or layout is lost when switching — the IC view code stays intact.
