# 0033. Use Simple Neovim Compatibility

Date: 2026-06-23
Status: Accepted

## Context

The workbench should allow the existing Neovim setup to remain available during
the migration to Emacs. Neovim could be deeply integrated into the coding layout,
but that would make Emacs act more like an outer terminal multiplexer and less
like the primary editing environment.

## Decision

Use simple Neovim compatibility in the first pass.

Provide a command that opens Neovim inside `vterm`.

Do not make Neovim the center editor in the default coding layout. The default
coding layout remains:

```text
Dirvish | Emacs code buffer | profile default AI
```

## Consequences

Neovim remains available as a fallback for existing workflows and muscle memory.

The first-pass workbench still commits to native Emacs editing as the primary
path.

A deeper layout such as `Files | Neovim | AI` can be considered later if simple
compatibility is not enough.
