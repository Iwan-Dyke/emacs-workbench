# Testing Strategy

## Principles

1. Test logic, not Doom. The workbench has meaningful logic (parsing, state
   management, data transforms) that can and should be tested without a full
   Doom Emacs environment.
2. Don't copy functions into tests. Load the real source with Doom stubs
   injected, so tests drift-proof against refactors.
3. Behaviour tests are expensive — use them sparingly for integration seams
   that can't be covered by unit tests.
4. Shell scripts get syntax checking (already done via `just check`) plus
   targeted unit tests for pure helper functions.

## Test Layers

### Layer 1: Unit Tests (ERT, batch Emacs — fast, CI-friendly)

**Runner:** `emacs --batch --no-init-file -l ert -l test/test-helper.el -l test/<file>.el -f ert-run-tests-batch-and-exit`

**Scope:** Pure functions, data transforms, state machines, predicates. Anything
that takes input → returns output without needing windows, frames, or Doom
subsystems.

**Stubbing approach:** A shared `test/test-helper.el` that:
- Provides fake implementations of Doom primitives (`+workspace-exists-p`,
  `+workspace-current-name`, `+workspace-switch`, `load!`, etc.)
- Loads real source files from `doom/modules/` so tests run against actual code
- Sets up `cl-letf` helpers for common overrides (shell calls, buffer state)

**What to unit test:**

| Module | Functions | Priority |
|--------|-----------|----------|
| tools/jira.el | `workbench-jira-days-since-update`, `workbench-jira-error-p`, `workbench-jira-error-reason`, fetch result parsing (stub shell output) | High |
| workflows/command-centre-data.el | `workbench-cc--team-attention-items` | High |
| workflows/command-centre-svg.el | `workbench-cc--darken`, `workbench-cc--lighten` | Medium |
| workflows/org.el | `workbench-org--format-ticket`, `workbench-org--adr-title`, `workbench-org--adr-node-id` | Medium |
| workflows/project-dashboard-data.el | `workbench--dashboard-description`, `workbench--dashboard-languages`, `workbench--dashboard-cicd` | Medium |
| tools/files.el | `workbench--directory-name`, `workbench--files-real-dired-p` | Low (trivial) |
| tools/terminals.el | toggle state logic (hash table ops) | Low (already tested) |
| tools/git.el | toggle state logic (same pattern) | Low |
| system/core.el | profile detection (daemon name parsing) | Low |
| workflows/coding.el | `workbench--project-identity-name` | Low (already tested) |

### Layer 2: Behaviour Tests (ERT, daemon Emacs — slower, confirms integration)

**Runner:** A script that starts a headless workbench daemon with a test profile,
runs ERT tests inside it via `emacsclient --eval`, then stops the daemon.

```bash
#!/usr/bin/env bash
# test/run-behaviour-tests.sh
set -eu
profile="workbench-test"
emacs --daemon="$profile" --eval '(load "~/.config/doom/init.el")'
emacsclient --socket-name "$profile" --eval '
  (progn
    (load (expand-file-name "test/behaviour-test.el" doom-user-dir))
    (ert-run-tests-batch-and-exit))'
emacsclient --socket-name "$profile" --eval '(kill-emacs)'
```

**Scope:** Workspace creation, persp-mode hooks, window layouts, keybinding
presence. Tests that need the actual Doom infrastructure running.

**What to behaviour test:**

| Concern | Test approach |
|---------|--------------|
| Startup workspaces exist | Assert workspaces "agenda", "ai", "files" exist after init |
| Keybindings resolve | Assert `(key-binding (kbd "SPC e"))` is `workbench/open-project-tree` |
| Profile detection | Daemon named `workbench-work` → `workbench/profile` is "work" |
| Command centre loads (work) | `workbench-cc--buffer-name` buffer exists after startup |
| Jira timer starts when configured | `workbench-jira--timer` is non-nil |

**What NOT to behaviour test:**
- Window geometry/pixel layout (too fragile, too slow)
- Actual vterm process spawning (needs real TTY)
- Full async fetch pipeline (test data layer in unit tests instead)
- SVG rendering (visual — trust the renderer, test the data)

### Layer 3: Shell Script Tests (bash -n + optional bats)

**Already covered by `just check`:** syntax validation (`bash -n`) and
shellcheck for all scripts.

**Optional addition:** [bats](https://github.com/bats-core/bats-core) tests for
pure helper functions in `bin/install`:

- `render_wrapper` — given profile, produces correct shebang + exec line
- `wrapper_is_managed` — detects managed vs unmanaged wrappers
- `find_doom_bin` — locates doom binary

These are small and stable enough that the syntax + shellcheck coverage is
sufficient for now. Add bats only if install logic gets more complex.

## File Layout

```
test/
├── test-helper.el           # Doom stubs, source loading, shared fixtures
├── workbench-test.el        # Legacy tests (migrate to new structure)
├── unit/
│   ├── test-jira.el         # Jira parsing, date math, error predicates
│   ├── test-command-centre.el  # Attention items, colour math
│   ├── test-org.el          # Ticket formatting, ADR parsing
│   ├── test-dashboard.el    # Description extraction, language counting, CI/CD
│   ├── test-files.el        # Directory naming, dired predicates
│   ├── test-terminals.el    # Popup state management
│   └── test-git.el          # Popup magit state management
├── behaviour/
│   ├── test-startup.el      # Workspace existence after init
│   ├── test-keybindings.el  # Key → command resolution
│   └── test-profile.el      # Profile detection and config loading
└── run-behaviour-tests.sh   # Daemon-based behaviour test runner
```

## test-helper.el Design

```elisp
;;; test/test-helper.el -*- lexical-binding: t; -*-
;; Minimal Doom stubs so modules can be loaded in batch Emacs.

(require 'cl-lib)

;; Doom primitives that modules reference at load time
(defvar doom-user-dir (expand-file-name "doom/" (file-name-directory
  (directory-file-name (file-name-directory load-file-name)))))

(defmacro load! (file &optional _dir _noerror)
  "Load FILE relative to doom-user-dir."
  `(load (expand-file-name ,file doom-user-dir) nil t))

(defmacro after! (_feature &rest body)
  "Execute BODY immediately (stub — no deferred loading in tests)."
  `(progn ,@body))

(defmacro add-hook! (hook &rest body)
  "Stub add-hook! — just execute the body to define functions."
  (declare (indent 1))
  (if (and (consp (car body)) (eq (caar body) 'defun))
      `(progn ,@body)
    `(progn ,@body)))

(defmacro map! (&rest _args) nil)
(defmacro set-formatter! (&rest _args) nil)

;; Workspace stubs (default: no workspaces exist)
(defvar workbench-test--workspaces '())

(defun +workspace-exists-p (name)
  (member name workbench-test--workspaces))

(defun +workspace-current-name ()
  "default")

(defun +workspace-switch (_name &optional _create) nil)
(defun +workspace/new () nil)
(defun +workspace/display () nil)

;; Doom variables
(defvar doom-modules '())
(defvar doom-disabled-packages '())

(provide 'test-helper)
```

## Running Tests

### Unit tests only (fast — suitable for pre-commit, CI)

```bash
just test
```

Update the justfile recipe to find all unit test files:

```just
test:
    emacs --batch --no-init-file -l ert -l test/test-helper.el \
      $(find test/unit -name '*.el' -exec printf '-l %s ' {} \;) \
      -f ert-run-tests-batch-and-exit
```

### Behaviour tests (slow — run manually or in CI nightly)

```bash
test/run-behaviour-tests.sh
```

### All tests

```bash
just test-all
```

## Migration Path

1. **Create `test/test-helper.el`** with the Doom stubs above.
2. **Create `test/unit/test-jira.el`** as the first new unit test file — the
   Jira module has the most testable logic and the highest value.
3. **Migrate existing tests** from `workbench-test.el` into the new structure,
   removing the copied function bodies in favour of loading from source.
4. **Add behaviour tests** only after unit coverage is solid.
5. **Update `just test`** to use the new structure.
6. **Add `just test-all`** once behaviour tests exist.

## What NOT to Test

- Doom's own functionality (workspace switching, evil bindings, persp-mode)
- Third-party packages (Magit, Dirvish, Treemacs, vterm internals)
- Visual output (SVG pixel positions, face rendering, terminal colours)
- Network-dependent calls (actual Jira CLI calls — stub at shell boundary)
- Timing-sensitive code (resize timers, idle hooks — too flaky in batch)

## Coverage Goals

Not aiming for a percentage target. Instead:

- Every data-parsing function has at least one happy-path and one error-path test
- Every state machine (popup toggle, cache lifecycle) has on/off/edge-case tests
- Behaviour tests cover the "did the system boot correctly" question only
- Shell scripts pass syntax + shellcheck (already done)

When a bug is found, write a test that reproduces it before fixing it.
