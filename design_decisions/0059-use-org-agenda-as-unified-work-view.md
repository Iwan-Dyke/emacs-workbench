# 0059. Use Org Agenda as Unified Work View

Date: 2026-06-29
Status: Accepted

## Context

The workbench is becoming the primary working environment, replacing the
tmux + terminal workflow. In the tmux setup, a dedicated `jira` window
runs `j mine` / `j board` for task visibility. The Emacs equivalent
needs to provide the same at-a-glance view without duplicating Jira as
the system of record.

Org agenda can aggregate TODO items, scheduled tasks, and custom views.
Combined with shell integration, it can pull live Jira state into org
headings that are linkable from the knowledge graph (org-roam nodes,
meeting notes, decisions).

The `j` CLI wrapper enforces team rules (WIP limits, templates,
two-week rule) and must remain the interaction layer for Jira mutations.
Org should not bypass `j` or talk to the Jira API directly.

## Decision

Use org agenda as the unified work view in the Emacs workbench.

Jira integration follows Option C: org is the view layer, Jira is the
store.

Specifics:

1. **Jira state as read-only org headings.** A refresh command shells
   out to `j mine` (and optionally `j board`), parses the output, and
   writes/updates headings in a dedicated `jira.org` file inside
   `org-directory`. These headings carry properties (`ID`, `STATUS`,
   `ASSIGNEE`, `UPDATED`) so they are linkable from org-roam.
   Refresh runs automatically on a timer (every N minutes) while
   Emacs is running, keeping the view current without manual
   intervention.

2. **Agenda sits next to the command centre.** The work profile opens
   the command centre (ADR 0058) on startup. Org agenda is the next
   workspace over (`SPC TAB` to switch). This keeps the landing
   screen focused on navigation while agenda is one keystroke away.

3. **Mutations stay in `j`.** Starting, closing, commenting, and
   creating tickets happen through `j` in vterm. Org does not write
   back to Jira.

4. **Org tasks complement Jira.** Personal TODOs (under 30 minutes,
   per team rules) live in org without a Jira ticket. They appear in
   agenda alongside Jira items.

5. **Custom agenda views.** At minimum: today (Jira + org tasks),
   stale (items not updated in 14 days), and inbox (uncategorised
   captures).

6. **Linkable work items.** Because Jira headings have stable IDs
   (the ticket key), org-roam nodes, meeting notes, and decision
   records can link to them with `[[id:PROJ-42]]`.

## Consequences

The morning workflow becomes: open Emacs → command centre (ADR 0058) →
switch one workspace to agenda showing current Jira state + org tasks →
act on items via `j` in vterm or org for personal tasks.

Jira remains the team-visible source of truth. No sync drift risk
because org never writes back.

The `jira.org` file is generated/ephemeral — it can be gitignored or
regenerated at any time.

Parsing `j` CLI output introduces a coupling to its format. If `j`
output changes, the parser needs updating. Using `--plain --no-headers`
output minimises this risk.

Personal org TODOs that cross the 30-minute threshold should become
Jira tickets (via `j new`) — the agenda view should make this obvious
by showing estimated effort.
