# 0063. Team Lead Command Centre Layout

Date: 2026-07-01
Status: Accepted

## Context

ADR 0061 introduces a switchable command centre view. This ADR defines the
layout and data sources for the team lead view.

The team lead's daily questions:
1. Where is everything on the board? (flow)
2. What's stuck or needs attention? (blockers)
3. What happened recently? (activity)
4. Is anyone overloaded? (capacity)

The existing IC view answers "what am I working on?" — the team lead view
answers "what does my team need from me?"

The team is identified by its UUID in the Jira `team` JQL field (ADR 0062).

## Decision

### Layout (top to bottom)

```
┌─────────────────────────────────────────────────────────┐
│ Header: greeting │ date                                  │
├─────────────────────────────────────────────────────────┤
│ WIP Gauge (team)    │  BOARD SWIMLANES                  │
│    N / limit        │  Next → In Progress → Review      │
│    ● ● ○ ○ ○       │  (tickets grouped by person)       │
├─────────────────────────────────────────────────────────┤
│ ⚠ ATTENTION                                             │
│   KEY-45  Person A   17d no update                      │
│   KEY-47  Person A   17d no update                      │
│   KEY-294 Person B    3d no comment today               │
├─────────────────────────────────────────────────────────┤
│ ACTIVITY (last 48h)                                     │
│   KEY-428 Person C: "comment snippet"           2h ago  │
│   KEY-397 Person D: "comment snippet"           5h ago  │
│   PR #142 merged: repo-name (Person C)       yesterday  │
├─────────────────────────────────────────────────────────┤
│ INFRASTRUCTURE (condensed)                              │
│   ● Colima  ● Docker (3)  ● Spark                      │
└─────────────────────────────────────────────────────────┘
```

### Section 1 — Header + WIP Gauge

- Greeting, date, profile indicator ("Team Lead · <team name>")
- WIP gauge: count of team's In Progress items vs TEAM_WIP_LIMIT
- Colour: green (≤ limit), amber (limit+1), red (> limit+2)

### Section 2 — Board Swimlanes

Tickets filtered by team UUID, grouped by status column (Next, In Progress,
Review), then by assignee within each column.

Per ticket:
- Key, truncated summary
- Assignee (first name only for space)
- Days since last update
- Comment indicator: ● (commented today), ○ (no comment today)
- Colour: green (<3d), amber (3-7d), red (>7d since update)

### Section 3 — Attention (Blockers & Nudges)

Items requiring team lead action, ranked by urgency:
1. Tickets In Progress >14 days (two-week rule violation)
2. Tickets with no comment in 7+ days (radio silence)
3. Tickets with no comment in 3+ days (may need a check-in)
4. Unassigned tickets tagged to the team

Each shows: key, assignee, days since last update, reason for flagging.

### Section 4 — Activity Feed

Recent signals from the team (last 48 hours), most recent first:
- **Jira comments**: last comment on each active ticket (author, snippet, time)
- **Pull requests**: opened, merged, declined from team repos (Bitbucket API)
- **Commits**: by team members across code repos

Limited to ~8 items to avoid scroll.

### Section 5 — Infrastructure (Condensed)

Single row of status pips (Colima, Docker, Spark). Same as IC view but
compressed to one line since it's less relevant to the lead role.

### Data Sources

| Section | Source | Method |
|---------|--------|--------|
| Board swimlanes | Jira | `jira issue list --jql` with team UUID filter |
| Last comment | Jira | `jira issue view <KEY> --comments 1` per ticket |
| Attention | Derived | Computed from ticket age + comment recency |
| PR activity | Bitbucket REST API | Recent PRs by team members |
| Team commits | Git | `git log --author=<member> --since=48h` across repos |
| Infrastructure | Local | colima status, docker ps, curl spark |

### Team Member List

Stored in `j.conf` for reuse by both `j team` and the command centre:

```bash
TEAM_MEMBERS="Alice,Bob,Carol,Dave"
```

Used for:
- Filtering git commits to team members
- Filtering Bitbucket PRs to team authors
- Identifying unassigned-but-team-tagged items

### Bitbucket PR Integration

The command centre calls the Bitbucket REST API directly (same token/URL from
credentials config) to fetch recent PRs by team members. This avoids coupling
to the `b` wrapper and keeps the dashboard self-contained.

Future work: add `b prs` command for terminal use.

### Refresh Behaviour

- Auto-refresh every 5 minutes (same as IC)
- Manual refresh with `r`
- Jira calls are the bottleneck (~2-5s for a team's worth of tickets)
- Cache ticket details between refreshes; only refetch if >5 min old

## Consequences

- The team lead sees board health immediately on opening Emacs — no context
  switch to browser Jira or terminal.
- Stale/blocked work surfaces automatically — the lead doesn't have to
  remember to check.
- Activity feed replaces standup prep: "what did people do yesterday?" is
  answered before the meeting.
- Bitbucket API adds a network dependency and requires the token to be set.
  Degrades gracefully (shows "no PR data" if unavailable).
- The TEAM_MEMBERS list in config needs manual maintenance when people
  join/leave the team.
- Comment fetching is N+1 (one call per ticket). For ~10 tickets this is
  acceptable (~3s). If WIP grows further, consider batching or caching.
- PR data depends on knowing which repos the team works on. Initial
  implementation scans repos under the relevant project; can be narrowed
  via config if needed.
