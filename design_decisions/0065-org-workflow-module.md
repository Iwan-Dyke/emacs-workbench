# 0065. Org Workflow Module

Date: 2026-07-03
Status: Accepted

## Context

ADR 0024 established org-roam as the knowledge graph layer. ADR 0059
defined org agenda as the unified work view. ADR 0060 defined
auto-discovery of ADRs and reMarkable content. None of these have been
implemented — org is enabled in `init.el` but no custom module exists.

The workbench needs a single org workflow module that wires these pieces
together: org-roam database, agenda views, Jira sync into `jira.org`,
ADR discovery, and keybindings.

## Decision

Create `modules/workflows/org.el` as the org workflow module.

### org-directory and org-roam

- `org-directory` set to `~/org/`
- org-roam database in `~/org/.org-roam.db`
- org-roam directory is `~/org/`
- The installer creates `~/org/` and runs `git init` if the directory
  does not exist (ADR 0060 update)

Initial `~/org/` structure created by the installer:

```text
~/org/
  inbox.org
  jira.org          (generated, gitignored)
  notes/
  projects/
  resources/
  workflows/
```

### Jira sync — `jira.org`

- Consumes data from the shared Jira fetch module (ADR 0064)
- Writes/updates `~/org/jira.org` with one heading per In Progress ticket
- Each heading has properties: `ID` (ticket key), `STATUS`, `ASSIGNEE`,
  `UPDATED`, `TYPE`, `EXTERNAL_URL`
- Headings are org-roam nodes (linkable via `[[id:ACME-42]]`)
- Refresh piggybacks on the shared Jira timer (every 5 minutes)
- `jira.org` is gitignored — it is regenerated, not authored

Heading format:

```org
* TODO ACME-42 Summary of the ticket
:PROPERTIES:
:ID: ACME-42
:TYPE: WorkItem
:STATUS: In Progress
:ASSIGNEE: someone
:UPDATED: 2026-07-01
:END:
```

### Agenda views

Custom agenda commands:

- **Today** (`d`): all In Progress Jira items + any org TODO items
  scheduled for today. This is a visibility view, not an action list.
- **Stale** (`s`): items with UPDATED older than 14 days (two-week
  rule).
- **Inbox** (`i`): items in `inbox.org` not yet refiled.

Agenda files: `~/org/jira.org`, `~/org/inbox.org`, and any files in
`~/org/projects/`.

### ADR discovery

Interactive command `workbench-org/discover-adrs` that:

1. Scans `~/code/*/design_decisions/*.md`
2. For each ADR, creates/updates an org-roam node in `~/org/projects/`
3. Node properties: `ID` (repo/filename), `TYPE` Decision, `SOURCE`
   (file path), `PROJECT` (repo name)
4. The node body links to the source markdown file — content is not
   copied
5. Stale nodes (source file deleted) are flagged with a `STALE` tag

### Capture templates

Deliberate write-ups, not quick thoughts (notebook handles those):

- **Note** (`n`): structured note filed to `~/org/notes/`
- **Decision** (`d`): decision record filed to `~/org/projects/`
- **Meeting** (`m`): meeting note filed to `~/org/notes/`

### Keybindings

Under `SPC n` (Doom notes convention):

```text
SPC n a   open org agenda
SPC n f   org-roam find node
SPC n i   org-roam insert link
SPC n b   org-roam backlinks buffer
SPC n c   org capture
SPC n d   discover/refresh ADR nodes
SPC n j   open jira.org
```

### Startup workspace

The agenda opens as a startup workspace. Startup order becomes:

```text
dashboard → agenda → ai → files
```

The session module calls the agenda view after creating the workspace.

## Consequences

Org becomes a first-class workflow in the workbench with its own module,
startup workspace, and keybinding surface.

Jira visibility is available both in the command centre (SVG/text
dashboard) and in org agenda (structured, linkable, filterable). They
share the same data source.

The knowledge graph grows automatically via ADR discovery and Jira sync.
Meeting notes, decisions, and project observations can link to tickets
and ADRs without manual node creation.

`org-roam` must be added to `packages.el`. The org-roam database build
runs on first launch after install.

The `~/org/` directory is a separate git repo from the workbench. The
workbench installer bootstraps it but does not manage its commits.
