# 0021. Use Profile-Specific AI Defaults

Date: 2026-06-22
Status: Accepted

## Context

The workbench supports personal and work profiles. AI tool usage differs by
profile.

The personal workflow should default to Codex. The work workflow should default
to Kiro, with Claude also available. The current work setup commonly uses Yazi,
Kiro, Claude, and Neovim with a Kiro pane on the right.

The Emacs coding layout has a right-side AI window, so that AI window should
respect the active profile.

## Decision

Make the default AI tool profile-specific.

Profile defaults:

```text
personal -> Codex
work     -> Kiro
```

The command-driven coding layout should open the profile's default AI tool in
the right-side AI window.

Provide explicit AI commands regardless of profile:

```text
open Codex
open Kiro
open Claude
open profile default AI
```

All first-pass AI tools run in `vterm`.

## Consequences

`workbench personal` opens a personal workflow that defaults to Codex.

`workbench work` opens a work workflow that defaults to Kiro while keeping Claude
available.

The AI workflow stays profile-aware without hardcoding work behavior into the
global config.
