# 0015. Use vterm as Terminal Engine

Date: 2026-06-22
Status: Accepted

## Context

The workbench needs terminal support for shells, AI CLIs, Neovim compatibility,
Yazi compatibility, and other terminal applications.

Emacs provides several shell and terminal options, including `shell`, `eshell`,
`term`, `eat`, and `vterm`. Some are more Emacs-native, but the first-pass
workbench needs reliable terminal emulation for full-screen terminal programs.

Doom documents `vterm` as the strongest terminal emulation option, with the
tradeoff that it requires native module support and build dependencies.

## Decision

Use `vterm` as the first-pass terminal engine.

Use it for:

- shell buffers
- the AI side window
- Claude, Codex, and Kiro CLI sessions
- Neovim compatibility
- Yazi compatibility
- other terminal UI tools when needed

Do not add `eshell` or `eat` as first-pass terminal systems.

## Consequences

Terminal applications are more likely to behave correctly inside Emacs.

The install and doctor scripts need to check for `vterm` requirements, including
Emacs dynamic module support and native build dependencies.

The workbench remains focused on one terminal engine. Other Emacs shell systems
can be considered later if a specific workflow needs them.
