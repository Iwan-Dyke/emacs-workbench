# 0047. Use tmux-Style Window Navigation Keys

Date: 2026-06-24
Status: Accepted

## Context

The user's Neovim and tmux setup moves between panes with `C-h`, `C-j`, `C-k`,
and `C-l`. Preserving that muscle memory in the workbench means binding the same
keys to Emacs window motions.

In Emacs, `C-h` is the help prefix by default, so it never reaches a window
motion. Doom already provides help under the `SPC h` leader, so `C-h` can be
repurposed without losing access to help.

The coding layout also docks Treemacs as a left side window (ADR 0043). Plain
directional window motion does not always step into or out of such a side
window cleanly, which breaks the "move into the tree" expectation.

## Decision

Bind window navigation to the Neovim motions:

```text
C-h -> window left
C-j -> window down
C-k -> window up
C-l -> window right
```

`C-h` is taken from the help prefix; help remains available on `SPC h`.

`C-h` and `C-l` are Treemacs-aware:

- `C-h` moves to the window on the left, and when there is none but Treemacs is
  open, it jumps into the Treemacs tree.
- `C-l` moves to the window on the right, and from the Treemacs tree it returns
  to the editing window.

`C-j` and `C-k` use the plain evil window motions.

The motion commands live in `system/interface.el`; the bindings live in
`system/keybindings.el` (ADR 0007).

## Consequences

Pane navigation matches the user's tmux and Neovim reflexes, including moving in
and out of the Treemacs side window.

`C-h` no longer opens help; help is reached through `SPC h`.

The Treemacs-aware fallbacks mean the left and right motions depend on the
coding-layout tree behavior from ADR 0043.
