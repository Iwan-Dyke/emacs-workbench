# 0024. Use org-roam for Private Knowledge Graph

Date: 2026-06-22
Status: Accepted

## Context

The workbench should support a private knowledge graph for notes, resources,
project links, reMarkable/PDF material, workflows, Jira/GitHub work items, and
cross-project knowledge.

Project-specific architecture decisions should remain in each project repo as
Markdown ADRs so other people can read and use them without Emacs.

The private knowledge graph should be designed with future RDF/SPARQL export in
mind, but RDF export does not need to exist in the first pass.

## Decision

Use Org and org-roam for the private top-layer knowledge graph.

Keep the knowledge graph outside `emacs-workbench`, in a separate private repo.

Use this first-pass knowledge repo structure:

```text
knowledge/
  inbox.org
  notes/
  projects/
  resources/
  workflows/
```

Use org-roam for graph navigation, node creation, backlinks, and note lookup.

Keep project-local ADRs as Markdown files in their own project repos. Org-roam
notes may link to ADR files or represent them as graph nodes, but Org does not
replace the project ADR source of truth.

Use RDF-ready metadata conventions:

- every meaningful Org heading gets a stable human-readable `ID`
- `TYPE` defines what kind of node it is
- tags support discovery
- properties define structured facts
- links define relationships
- external systems use generic metadata such as `SOURCE`, `EXTERNAL_ID`,
  `EXTERNAL_URL`, and `EXTERNAL_STATUS`

Initial node types:

```text
Project
Decision
WorkItem
Feature
Story
Task
Bug
Note
Tool
Workflow
Person
Resource
```

`Feature`, `Story`, `Task`, and `Bug` are first-class types and are also treated
conceptually as work items.

## Consequences

The workbench supports a graph-oriented knowledge workflow from the first pass.

Project documentation remains portable and readable without Emacs.

The graph layer can connect project ADRs, PDFs, reMarkable exports, external
work items, tools, people, and workflows across projects.

org-roam introduces an additional package and database layer, but it aligns with
the desired knowledge graph direction.

RDF/SPARQL export remains future work. The first pass focuses on stable IDs,
consistent properties, and useful links so export is possible later.
