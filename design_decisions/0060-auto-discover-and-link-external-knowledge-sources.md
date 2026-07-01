# 0060. Auto-discover and Link External Knowledge Sources

Date: 2026-06-29
Status: Accepted

## Context

ADR 0024 established org-roam as the private knowledge graph with node types
including Project, Decision, WorkItem, Resource, and others. Knowledge
currently lives in multiple places:

- **ADRs** in `~/code/*/design_decisions/` (markdown, per-repo)
- **reMarkable** notebooks and pages (handwritten notes, sketches, annotated
  PDFs on reMarkable Cloud)
- **General notes** captured in org

The knowledge graph is most useful when it connects these sources without
moving the source of truth. ADRs should stay as markdown in their repos.
reMarkable content should stay in reMarkable Cloud. Org-roam provides the
unified view and linking layer.

Manual node creation doesn't scale across 10+ repos and a growing tablet
library. Auto-discovery makes the graph useful without ongoing maintenance
overhead.

## Decision

Auto-discover external knowledge sources and represent them as linkable
org-roam nodes.

### ADR discovery

1. Scan `~/code/*/design_decisions/*.md` for ADR files.
2. For each ADR, create or update an org-roam node with:
   - `ID`: derived from repo + filename (e.g. `myproject/0007-whatever`)
   - `TYPE`: Decision
   - `SOURCE`: file path to the markdown ADR
   - `PROJECT`: repo name
   - Title and status extracted from the markdown heading/frontmatter
3. The org-roam node links to the source file — it does not copy content.
4. Run on demand (interactive command) or on workspace open. Not real-time.
5. Stale nodes (ADR file deleted) are flagged, not auto-removed.

### reMarkable integration

1. Use `remarkapy` (Python, PyPI) to list and download notebooks/pages
   from reMarkable Cloud.
2. Export as PDF (for visual content) or rendered markdown (via
   `remarkablesync` AI transcription) into a local `~/org/resources/`
   directory.
3. For each pulled item, create an org-roam node with:
   - `ID`: reMarkable document UUID
   - `TYPE`: Resource
   - `SOURCE`: reMarkable Cloud
   - `EXTERNAL_ID`: reMarkable document ID
   - Link to the local exported file
4. Run on demand. User selects which notebooks/pages to pull — not a
   full blind sync.
5. Pulled resources can then be linked from any org-roam node (project,
   decision, work item) to build up the graph.

### General notes

Captured via org capture templates into `~/org/inbox.org`. Refiled into
appropriate locations over time. No auto-discovery needed — these are
authored directly in org.

Exact hierarchy within `~/org/` is intentionally left to evolve with use.
The initial structure from ADR 0024 applies:

```text
~/org/
  inbox.org
  notes/
  projects/
  resources/
  workflows/
```

`~/org/` is a git repo (private). This provides backup, history, and
cross-machine sync. Generated files (`jira.org`) and large binary
exports (reMarkable PDFs) should be gitignored or handled separately
to keep the repo clean.

## Consequences

The knowledge graph grows automatically as repos gain ADRs and reMarkable
content is pulled in. Cross-project discovery becomes possible (e.g. "show
all decisions linked to the infrastructure project").

ADR source of truth remains in repos — other team members read them without
Emacs. Org-roam is a personal overlay.

reMarkable integration adds a Python dependency (`remarkapy`) and requires
reMarkable Cloud authentication (device token). This is a one-time setup.

The scanner introduces a convention: repos must use `design_decisions/` as
the ADR directory name. This matches existing coding standards.

If a repo uses a different ADR location, it won't be discovered until the
scanner is configured to look there. This is acceptable — consistency is
preferred over flexibility.

AI transcription of handwriting (via `remarkablesync`) is optional and may
have quality/cost implications. PDF export is the reliable baseline.
