# 0062. Add j team Command

Date: 2026-07-01
Status: Accepted

## Context

The Jira board uses a custom field (team field, stored as `customfield_NNNNN`)
to tag tickets with their team. The existing `j` commands (`j board`, `j mine`,
`j wip`) show the whole project — all teams together.

As team lead, the useful view is tickets owned by your team filtered by status.
The jira-cli supports JQL queries. Jira Cloud's `team` JQL keyword requires
the team UUID (not the display name).

## Decision

Add a `j team [TEAM_NAME]` command that lists tickets filtered by the team
field.

### Behaviour

```bash
j team                  # Uses TEAM from j.conf
j team-wip              # WIP breakdown by assignee within team
j team-stale            # Stale items within team (>14 days)
```

Output shows tickets grouped by status column:

```
=== My Team ===

NEXT (0)
  (empty)

IN PROGRESS (4)
  KEY-123  Some work item        Alice    2d
  KEY-124  Another item          Bob      1d
  ...

REVIEW (1)
  KEY-125  Review item           Carol    0d

WIP: 4 / 2 (team limit)
```

### Configuration

Add to `j.conf`:

```bash
TEAM="My Team"                                        # Display name
TEAM_FIELD="customfield_NNNNN"                        # Custom field ID (for REST API)
TEAM_ID="<uuid>"                                      # Team UUID (for JQL)
TEAM_MEMBERS="Alice,Bob,Carol"                        # Comma-separated display names
```

### JQL

The Jira Cloud `team` JQL field requires the team UUID, not the display name:

```
project = XXX AND team = "<uuid>" AND status IN ("Next", "In Progress", "Review")
```

The UUID can be found via the Jira REST API (inspect the team custom field on
any ticket assigned to the team), or from the team page URL in Jira Cloud.

### Additional subcommands

- `j team` — board view filtered to team
- `j team-wip` — WIP count by assignee within the team
- `j team-stale` — items with no update in 14 days, within the team

These mirror the existing board-level commands but scoped.

## Consequences

- Team lead gets a terminal command for quick checks without Emacs.
- The command centre (ADR 0063) reuses the same JQL for its data collection.
- `TEAM_FIELD` is configurable because custom field IDs differ between Jira
  instances — other teams can use this if they adopt `j`.
- The `jira-cli` `--jql` flag doesn't support `--columns` filtering on all
  fields, so output formatting is handled by the wrapper.
- JQL queries are slightly slower than native list filters but the difference
  is negligible (<1s).
