# 0049. Run Global AI as a Full-Window Workspace

Date: 2026-06-24
Status: Accepted

## Context

ADR 0034 split AI into two scopes: global/session AI and project/layout AI. ADR
0048 implemented the project pane (toggled, far-right, `*project-<tool>*`) but
explicitly deferred the global/session AI as "a separate issue."

The first implementation of global AI opened each tool in a reusable vterm
buffer with `pop-to-buffer`, sharing whatever window happened to be selected.
That did not match the user's tmux/Neovim habit, where a session-level agent is
a full-screen context of its own, not a pane wedged into the current layout.

The workbench already treats Doom workspaces as tmux-like tabs (ADR 0037), and
`ai` is one of the intended context tabs (ADR 0038).

## Decision

Run the global/session AI as a full-window agent in a dedicated `ai` workspace.

- The profile default agent (ADR 0021) opens with
  `workbench/open-default-ai-workspace`, bound to `SPC a a`.
- It switches to (creating if needed) the `ai` workspace, launches the agent
  once in a `*<tool>*` buffer (ADR 0035), and fills the workspace with
  `delete-other-windows`. Re-running it just switches back to the live session.
- Tool launch commands live in one `workbench/ai-commands` alist
  (`kiro -> kiro-cli`), shared by both the global agent and the project panes.

This resolves the global/session AI deferred by ADR 0048. The project pane
behavior from ADR 0048 is unchanged.

## Consequences

Global AI now behaves like a tmux window: a full-screen agent context reachable
by switching to the `ai` workspace, distinct from the code-adjacent project pane.

The previous explicit per-tool global commands (`workbench/open-codex`, etc.) and
the single-buffer `pop-to-buffer` model are removed. A specific non-default agent
is now reached as a project pane (`SPC t c/k/x`) or by running its command in a
terminal workspace (`SPC t t`), rather than a dedicated global command per tool.

Tool-to-command mapping has a single source of truth, so adding or renaming a
tool is one alist edit.
