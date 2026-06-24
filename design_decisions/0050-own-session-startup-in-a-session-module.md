# 0050. Own Session Startup in a session Module

Date: 2026-06-24
Status: Accepted

Supersedes part of 0042.

## Context

ADR 0042 created two startup workspaces, `dashboard` and `files`, and said not to
auto-create an AI workspace yet. The startup logic lived in
`workflows/coding.el`, which is really about opening project workspaces.

Two things changed. First, the global AI now has a stable home as a full-window
`ai` workspace (ADR 0049), so opening it at startup is no longer speculative.
Second, the daemon's startup interacted badly with Doom's persp-mode session
handling: Doom autosaves the session on kill and tears a frame's workspace down
with the frame. On reconnect this could replay a stale window layout into the
just-born, still-tiny frame ("window too small to accommodate state"), corrupting
the startup workspaces and deleting the dashboard. This fights the tmux-like
reconnect lifecycle (ADR 0023), where closing a frame must leave the daemon's
workspaces intact.

## Decision

Introduce `doom/modules/workflows/session.el` as the owner of session startup.

- It opens the startup workspaces — `files` (browser) and `ai` (default agent,
  ADR 0049) — once, after the first graphic frame exists, then returns to the
  dashboard. The `display-graphic-p` guard and a once-flag keep the frameless
  daemon `emacs-startup-hook` and repeat frame creation from firing it.
- For the reconnect model (ADR 0023) it disables persp autosave
  (`persp-auto-save-opt 0`) and removes `+workspaces-delete-associated-workspace-h`
  from `delete-frame-functions` and `server-done-hook`, so closing a frame keeps
  the daemon's workspaces and no stale layout is replayed into a tiny frame.

Full session/layout restore stays deferred (ADR 0013).

## Consequences

Startup behavior and the persp-mode tweaks that keep it stable live in one module
named for the concern, instead of riding along in `coding.el`.

The startup set is now `dashboard` + `files` + `ai`, extending ADR 0042. The
broader default workspace set (code, notes, git) remains deferred (ADR 0038).

Because autosave is off, the workbench will not restore the previous session's
buffers or layouts on restart, which matches the start-clean decision (ADR 0013)
but means in-frame layout is not remembered across a daemon restart.
