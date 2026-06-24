# 0046. Mirror Neovim Leader Keys in the Coding Workflow

Date: 2026-06-24
Status: Accepted

## Context

The coding workflow aims to match the user's Neovim config closely enough to
preserve muscle memory. ADR 0033 keeps Neovim available as a fallback; this ADR
is about the leader-key surface itself.

Some current workbench bindings diverge from both Neovim and Doom defaults. Most
notably `SPC f f` opened the Dirvish file manager, whereas in Neovim
`<leader>ff` is fuzzy find-file and Doom's own default `SPC f f` is also
find-file.

## Decision

For the coding workflow, mirror the Neovim leader keys where practical,
preferring Doom/Emacs defaults when they already agree:

- `SPC f f` -> find file (fuzzy), matching Neovim `<leader>ff` and the Doom
  default
- `SPC e` -> toggle the project tree (Treemacs), matching Neovim `<leader>e`
- the Dirvish file manager moves off `SPC f f` to its own binding

Keep workbench-specific groups (profile, session AI, quit/session) on prefixes
that do not collide with this muscle-memory set.

Verify the chosen keys against the live Doom keymaps when testing, and adjust if
an enabled module already owns one.

## Consequences

Switching from Neovim to the workbench keeps the core find-and-navigate reflexes
intact.

Some earlier workbench bindings change — `SPC f f` in particular — so habits
formed on the workbench shift toward the Neovim and Doom convention.

The binding set is validated against the real keymap rather than assumed.
