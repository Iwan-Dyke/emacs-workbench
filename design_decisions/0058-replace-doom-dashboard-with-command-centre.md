# 0058. Replace Doom Dashboard With Command Centre

Date: 2026-06-28

## Status

Accepted

## Context

The Doom startup dashboard shows recent files and projects but provides no operational context for the working day. Opening Emacs should immediately show what matters: active tickets, repo health, and infrastructure state.

## Decision

Replace the Doom dashboard (work profile only) with a full-window SVG command centre that renders live operational data on startup.

### Sections

1. **Header** — date, profile, greeting
2. **Jira** — In Progress tickets (key, summary, days since last comment). Stale highlight (amber) if no comment in 2 days. Per-ticket indicator showing whether progress has been logged today.
3. **Git** — Recent projects (from workspace history), branch, dirty/clean/ahead/behind status.
4. **Recent activity** — Your commits from yesterday/today across active repos.
5. **Infrastructure** — Spark kernel (localhost:8889), Docker/Colima running, container count.

### Behaviour

- Fetches data live on startup (accepts 1-3s delay)
- Auto-refreshes every 5 minutes
- Manual refresh with `r`
- Read-only, non-interactive (no navigation needed)
- Work profile only — personal profile keeps Doom's default dashboard

### Rendering

- Programmatic SVG via Emacs built-in `svg.el`
- Full-window canvas, redrawn on refresh and window resize
- Respects the active workbench theme colours

## Consequences

- Startup is 1-3s slower on work profile (network calls to Jira)
- Requires `jira` CLI configured and authenticated
- Requires network access on startup (degrades gracefully if unavailable)
- Personal profile is unaffected
