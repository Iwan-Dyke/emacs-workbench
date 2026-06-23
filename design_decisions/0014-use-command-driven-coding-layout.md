# 0014. Use Command-Driven Coding Layout

Date: 2026-06-22
Status: Accepted

## Context

The preferred coding layout is:

```text
Files | Code | AI
```

This matches the desired development workflow: a file manager on the left, the
main editing area in the center, and an AI terminal on the right.

Emacs supports multiple buffers displayed in multiple windows inside a frame, so
this layout fits the native Emacs model. However, forcing the layout at startup
would make quick edits, Git work, notes, help, and other workflows less
flexible.

## Decision

Make `Files | Code | AI` the first designed coding layout, opened and restored
by an explicit workbench command.

Do not force the coding layout at startup. Startup should remain the Doom
dashboard.

The coding layout should create:

- left window: Dirvish/Dired file manager
- center window: primary code area
- right window: AI terminal

The center code area may be split further by the user for multiple files, such
as a source file and its test file.

## Consequences

The workbench gets a predictable coding layout without making every Emacs
session behave like a coding session.

The layout can be restored when other buffers disrupt the window arrangement.

The first implementation should treat the layout as a helper rather than a
strict window manager. More advanced project-aware or session-restoring layouts
can be considered later.
