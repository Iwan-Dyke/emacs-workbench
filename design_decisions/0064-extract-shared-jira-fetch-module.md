# 0064. Extract Shared Jira Fetch Module

Date: 2026-07-03
Status: Accepted

## Context

The command centre (ADR 0058) fetches Jira ticket data via shell calls to the
`jira` CLI. The org workflow module (ADR 0065) needs the same data to populate
`jira.org` and feed org agenda views.

Both consumers need: In Progress tickets (key, summary, type, assignee,
updated), Next queue, and Done items. Duplicating the fetch logic would create
two parsers that drift independently and double the API calls to Jira.

## Decision

Extract a shared Jira fetch module at `modules/tools/jira.el`.

The module provides:

1. **Data fetching functions** — shell out to `jira issue list` with
   appropriate flags, parse tab-delimited output into plists.
2. **Config variables** — project key, user, team ID, team members, status
   names. Currently defined in `command-centre-data.el`; move them here.
3. **Caching** — fetched data is stored in a module-level variable with a
   timestamp. Consumers call a single refresh function; if the cache is
   fresh (within TTL), the cached data is returned immediately.
4. **Timer** — a single background timer (default 5 minutes) refreshes the
   cache. Both command centre and org hook into the refresh via a hook or
   callback, rather than running their own timers.

The command centre and org module both require `modules/tools/jira` and read
from the shared cache. Neither calls the `jira` CLI directly.

Mutations (start, close, comment) remain in the `j` CLI via vterm. This
module is read-only.

## Consequences

Single source of truth for Jira data parsing. One set of API calls shared
across consumers.

Adding new Jira consumers (e.g. modeline ticket indicator, org-roam node
updater) becomes trivial — read from the cache.

The command centre's async subprocess fetch (child Emacs) needs refactoring
to use this module instead of inlining all config and fetch logic in the
subprocess form. The shared module's functions must be loadable both in the
main Emacs and in a batch subprocess.

Config variables move from `command-centre-data.el` to `modules/tools/jira.el`.
Profile `local.el` references update accordingly (variable names stay the same,
just the providing file changes).
