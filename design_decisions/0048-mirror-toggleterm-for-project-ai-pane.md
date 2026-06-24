# 0048. Mirror Neovim toggleterm for the Project AI Pane

Date: 2026-06-24
Status: Accepted

## Context

ADRs 0034, 0035, and 0039 define the project AI pane: a right-side terminal in
the coding layout, running the profile default tool, in `*project-<tool>*`
buffers, owned by the coding workflow.

The first implementation opened it as a side window that always opened and
focused, could not be dismissed with the same key, and was one third of the
frame wide. Testing showed this did not match the user's Neovim toggleterm AI
terminals, which are:

- vertical, 25 columns wide (the same width as the file tree)
- on the far right
- toggled with `<leader>tc` (Claude), `<leader>tk` (Kiro), `<leader>tx` (Codex)
- exclusive — only one AI terminal open at a time; opening one closes the others
- focus-taking on open
- navigable with `C-h`/`C-l` in and out, even in terminal mode

## Decision

Model the project AI pane on toggleterm:

- far-right vertical pane, 25 columns (matching the tree width)
- a normal window, not a side window, so window navigation works cleanly
- toggle: the same key opens (and focuses) and hides it; the session persists
  while hidden
- exclusive: opening one tool's pane hides any other project AI pane
- takes focus on open
- `C-h`/`C-l` navigate in and out of the pane while in vterm

Mirror the Neovim keys under the terminal prefix:

```text
SPC t c -> Claude project pane
SPC t k -> Kiro project pane
SPC t x -> Codex project pane
SPC a p -> profile default project pane
```

Scope: this covers only the project pane. The global/session AI (`SPC a a` and
its full-window behavior) is a separate, deferred issue.

## Consequences

The project AI pane matches the user's toggleterm muscle memory: same width,
toggle, exclusivity, and key letters.

The per-tool toggles live under `SPC t` (terminal), so the project AI letters
(`c` = Claude) differ from the global `SPC a` group (`c` = Codex). This
inconsistency is intentional for now and will be reconciled when the
global/session AI is redesigned.

vterm gains window-navigation keys so the AI pane is never a focus trap.
