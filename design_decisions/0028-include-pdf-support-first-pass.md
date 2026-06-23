# 0028. Include PDF Support in First Pass

Date: 2026-06-22
Status: Accepted

## Context

The workbench should support reading and linking PDF material, including PDFs
exported from reMarkable Paper Pro. PDF notes and resources should be able to
participate in the private Org/org-roam knowledge graph.

## Decision

Include PDF support in the first-pass workbench.

Use `pdf-tools` for PDF viewing and annotation inside Emacs.

Represent PDFs in the knowledge graph as `Resource` nodes with metadata such as
`KIND` and `FILE`.

Example:

```org
* Spark notebook from reMarkable
:PROPERTIES:
:ID: resource-spark-notebook-remarkable
:TYPE: Resource
:KIND: pdf
:FILE: ~/knowledge/resources/files/spark-notebook.pdf
:END:
```

Do not build reMarkable sync automation in the first pass.

## Consequences

PDF reading can happen inside the workbench instead of outside the Emacs
environment.

PDF resources can be linked from Org/org-roam notes and later included in an
RDF/SPARQL export model.

`pdf-tools` may require native build dependencies, so install and doctor scripts
should check it.

reMarkable integration starts as file-based: exported PDFs are linked from Org
notes rather than synced automatically.
