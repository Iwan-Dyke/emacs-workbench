# 0010. Use Space as Only Leader Key

Date: 2026-06-22
Status: Accepted

## Context

The existing Neovim and tmux workflow already uses Space as the primary leader
key, so Space is established muscle memory.

Adding a second leader such as comma could make some context-specific commands
shorter, but it would introduce another command surface to learn and maintain.

Ease of understanding and discoverability are more important than minimizing
every key sequence.

## Decision

Use Space as the only custom workbench leader key.

All custom global workbench commands should live under the Space leader tree.
Do not reserve comma as a local leader in the first version.

Use `which-key` as a required discoverability layer so leader groups and command
names are visible while learning and using the workbench.

Initial leader groups:

```text
SPC f   files
SPC b   buffers
SPC p   projects
SPC g   git
SPC t   terminals
SPC c   code
SPC n   notes
SPC a   AI
SPC x   diagnostics/problems
SPC w   windows
SPC q   quit/session
```

## Consequences

The keyboard interface has one primary command surface, which should be easier
to learn, document, and maintain.

Some context-specific actions may take more keystrokes than they would with a
secondary local leader.

Direct non-leader keys should be used sparingly and mostly follow Doom, Evil, or
Emacs conventions rather than creating a second custom interface.
