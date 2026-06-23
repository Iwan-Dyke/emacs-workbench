# 0030. Use Org and emacs-jupyter for Notebooks

Date: 2026-06-23
Status: Accepted

## Context

The current Neovim setup supports notebook-style work through Jupytext, Molten,
and remote Jupyter kernels. The Emacs Workbench should provide a notebook
workflow that is close to that model while integrating with Org and the private
knowledge graph.

Plain Org Babel can execute code blocks, but it is less close to the current
Jupyter-kernel workflow. Org plus `emacs-jupyter` provides a more comparable
model: Org documents with source blocks executed through Jupyter kernels.

## Decision

Use Org plus `emacs-jupyter` as the intended first-pass notebook direction.

Notebook-style work should use Org documents with Jupyter-backed source blocks
where practical.

Keep Neovim/Molten available through compatibility workflows for existing
notebook and Jupytext usage during migration.

## Consequences

Notebook work can integrate with Org notes, org-roam links, and the future
knowledge graph direction.

This is more complex than plain Org Babel and may require Jupyter kernel setup
and profile-specific environment configuration.

Existing `.ipynb` or Jupytext workflows do not need to be replaced immediately
because Neovim compatibility remains available.
