# 0051. Rebuild Full-Frame Dirvish in the Files Workspace on Entry

Date: 2026-06-24
Status: Accepted

## Context

The files workspace (ADR 0042, ADR 0050) is meant to be the visual browser, and
the richest form of that is full-frame Dirvish: the `parent | listing | preview`
layout. Two facts make that hard to deliver as a persistent workspace:

- Full-frame Dirvish is modal. On open it saves the window configuration, runs
  `delete-other-windows`, and lays out dedicated panes; on teardown it restores
  the saved configuration. So it collapses the moment a sibling window appears
  (e.g. a toggled AI pane) and cannot coexist with a multi-pane layout.
- It cannot be persisted. Testing showed full-frame Dirvish does not survive
  persp's window-config save/restore across a workspace switch — returning to
  the workspace yields a blank buffer, not the layout.

So `workbench/open-files` (SPC f m) stays a single, stable, Dirvish-styled Dired
window that coexists with other panes (the prior decision), but that is not the
full-frame experience the files workspace wants.

## Decision

Do not try to persist full-frame Dirvish. Rebuild it fresh each time the files
workspace is entered, and make the rebuild seamless by remembering where the
user was.

- On `persp-activated-functions`, when the activated workspace is `files`,
  deferred via `run-at-time` (so persp finishes restoring first), open full-frame
  Dirvish unless it is already showing.
- Track the current directory and file at point live while browsing, from a
  buffer-local `post-command-hook` in Dired buffers, skipping Dirvish's parent
  and preview panes (also `dired-mode` buffers). Tracking live rather than
  reading on exit is necessary: by switch time full-frame Dirvish has already
  collapsed and killed its index buffer, so the position is no longer readable.
- Rebuild at the tracked directory with point on the tracked file, instead of
  resetting to the project root.

## Consequences

The files workspace presents full-frame Dirvish automatically and returns to the
same directory and file across workspace switches, so the rebuild is not visible
as lost context.

Each entry runs `delete-other-windows` and reopens, so any split left in the
files workspace is discarded and the workspace is effectively reserved for the
browser. That is the intended role of this workspace.

`workbench/open-files` remains the non-modal, layout-friendly entry point (a
single Dired window) for browsing files beside other panes; full-frame is the
files workspace's mode, reachable elsewhere on demand with `F`.
