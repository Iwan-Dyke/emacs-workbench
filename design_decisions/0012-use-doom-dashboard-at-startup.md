# 0012. Use Doom Dashboard at Startup

Date: 2026-06-22
Status: Accepted

## Context

The workbench needs a clear first screen when Emacs opens without a file. The
current Neovim setup uses `alpha-nvim` as a startup dashboard with quick actions
and status information.

Doom provides a built-in dashboard that can serve the same role without building
a custom dashboard before the core workbench is usable.

## Decision

Use the Doom dashboard as the first startup screen.

Treat it as the Emacs equivalent of the current Neovim `alpha-nvim` dashboard.
Do not build a custom workbench dashboard in the first pass unless the Doom
dashboard blocks the workflow.

## Consequences

Startup has a familiar launcher-style entry point with minimal custom code.

The first pass can focus on core workbench behavior instead of dashboard
polish.

A later decision can replace or customize the dashboard if the workbench needs
project status, Org agenda information, AI shortcuts, or custom theme behavior
on startup.
