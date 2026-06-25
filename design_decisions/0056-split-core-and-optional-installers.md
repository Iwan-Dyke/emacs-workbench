# 0056. Split Core and Optional Installers

Date: 2026-06-25
Status: Accepted

## Context

The first bootstrap implementation put platform prerequisites, Doom setup,
wrapper installation, Doom sync, language servers, and formatters in
`bin/install`.

That made the one-command install work, but it mixed reliable core setup with
optional tool installation. Optional language tooling is more volatile: package
names differ by platform, ecosystem installers have their own PATH behavior, and
individual tools can fail without making Emacs or Doom unusable.

AI CLIs are not part of the installer. They remain user-managed and are only
reported by `bin/doctor`.

## Decision

Split installation into three scripts:

```text
bin/install                   core orchestration
bin/install.d/platform-tools  required platform prerequisites
bin/install.d/language-tools  optional language servers and formatters
```

`bin/install` remains the implementation behind top-level `install.sh`. It runs
the supported platform prerequisite installer, performs Doom checkout/install,
links this repo as the Doom config, installs launch wrappers, runs Doom sync/env,
then runs optional language-tool installation and the doctor report.

`bin/install.d/platform-tools` owns required platform packages needed for the
workbench to start and build Doom packages, such as Git, Emacs, ripgrep, and
build tooling.

`bin/install.d/language-tools` owns optional coding dependencies such as LSP
servers and formatters. It should be data-driven with package lists grouped by
provider (`brew`, `apt`, `npm`, `go`, `pipx`) so adding, removing, or renaming a
tool is a small list edit.

Language-tool installation failures should warn but not fail the whole
workbench install. `bin/doctor` remains the source of truth for what is
available after installation.

## Consequences

Core install behavior is easier to read and review.

Optional language-tool churn is isolated from Doom/bootstrap logic.

There are more scripts, but each script has a tighter responsibility and clearer
package lists.

The installer can stay one-command for normal use while still allowing targeted
reruns:

```bash
bin/install.d/platform-tools
bin/install.d/language-tools
```
