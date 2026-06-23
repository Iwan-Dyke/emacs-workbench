# 0004. Symlink Doom Config From Repo

Date: 2026-06-22
Status: Accepted

## Context

The Doom user configuration normally lives at `~/.config/doom`. The
`emacs-workbench` repository will contain the source version of that config
under `doom/`.

The desired development model is for changes made in the repository to be live
immediately without copying files back and forth.

## Decision

Make `~/.config/doom` a symlink to the repository's `doom/` directory.

The source of truth is:

```text
~/homelab/projects/emacs-workbench/doom
```

The live Doom config path points to it:

```text
~/.config/doom -> ~/homelab/projects/emacs-workbench/doom
```

## Consequences

Editing the repository updates the live Doom configuration immediately.

The install script must check for an existing `~/.config/doom`. If it is a real
directory or an unrelated symlink, the script should back it up or stop with a
clear message rather than overwrite it.

This model is simple during development and works well with a future standalone
GitHub repository.

The repo location becomes part of the live configuration, so moving the repo
requires recreating the symlink.
