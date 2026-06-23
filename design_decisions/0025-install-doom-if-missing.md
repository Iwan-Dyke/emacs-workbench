# 0025. Install Doom if Missing

Date: 2026-06-22
Status: Accepted

## Context

The workbench depends on Doom Emacs. A config-only installer would be safer and
simpler, but it would require a separate manual Doom installation step before
the workbench can run.

The project is intended to be a full workbench project rather than only a Doom
config directory.

## Decision

Make `bin/install` responsible for first-run setup, including Doom installation
when Doom is missing.

The installer should:

- check that Emacs exists
- install Doom into `~/.emacs.d` if missing
- link `~/.config/doom` to the repository's `doom/` directory
- run Doom sync
- avoid overwriting existing unrelated config without a clear backup or stop

## Consequences

New machine setup becomes closer to one command.

The installer has more responsibility and must be careful, idempotent, and clear
about changes.

Existing `~/.emacs.d` and `~/.config/doom` paths require guardrails so the
installer does not destroy unrelated user config.
