# 0067 — Add visual enhancements (lin, org-modern, hl-line)

## Status

Accepted

## Context

Custom buffers (command centre, repos, project dashboard) use text properties
and nerd-icons for visual styling, but lacked a current-line indicator. In
list-oriented buffers where you navigate with j/k, it's hard to see which item
is selected without a visible highlight.

Org agenda and org files used default Doom styling — functional but plain
compared to modern alternatives.

## Decision

Add three visual enhancement layers:

1. **lin** (GNU ELPA, Protesilaos Stavrou) — remaps hl-line-face per buffer
   to a style suited for line-selection modes. Enabled on:
   - `workbench-repos-mode` (repos dashboard)
   - `workbench-cc-mode` (command centre)
   - `org-agenda-mode`
   - `dired-mode`

2. **org-modern** (GNU ELPA, Daniel Mendler) — replaces org bullets with
   unicode symbols (◉○◈◇▸), formats checkboxes (☑◧☐), list markers (•◦),
   and prettifies timestamps/tags/keywords. Tables kept as-is.

3. **hl-line** (Doom :ui module) — global highlight line. Project dashboard
   buffers (`*workbench:*`) get hl-line via special-mode-hook.

All are display-only — no IO, no network, no data modification.

## Consequences

- Repos and command centre have a visible current-line highlight
- Org files and agenda look cleaner without functional changes
- Two new package dependencies (lin, org-modern) — both GNU ELPA, trusted maintainers
- No performance impact (font-lock/display properties only)
