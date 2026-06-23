# 0011. Use Dired and Dirvish as Primary File Manager

Date: 2026-06-22
Status: Accepted

## Context

The current workflow uses Yazi as a fast terminal file manager. The Emacs
Workbench should reduce context switching and make file operations part of the
same environment as buffers, projects, Git, notes, and terminals.

Keeping Yazi as the primary file manager would preserve existing habits, but it
would keep file management behind a terminal UI boundary. Emacs would have less
visibility into file operations and less ability to integrate them with the rest
of the workbench.

## Decision

Use Emacs-native Dired as the underlying primary file-management model, with
Dirvish as the first-pass enhanced file-manager UI.

Configure Dired and Dirvish in `doom/modules/tools/files.el`.

Keep Yazi available through a compatibility command, likely implemented with
vterm, but do not make it the primary file management workflow in the first
version.

## Consequences

File operations can integrate directly with Emacs buffers, projects, Magit,
TRAMP, search, and the workbench keybinding model.

Dired will require learning a different model than Yazi and may feel less visual
at first.

Dirvish adds another package and some configuration, but it may make the
workbench file-manager experience more comfortable than plain Dired alone.

Yazi remains available for terminal-native browsing, media-heavy directories, or
fallback workflows during migration.
