default:
    just --list

install:
    ./install.sh

sync:
    ./bin/sync

doctor:
    ./bin/doctor

check:
    bash -n ./install.sh ./bin/install ./bin/install.d/platform-tools ./bin/install.d/language-tools ./bin/sync ./bin/doctor ./bin/workbench
    command -v shellcheck >/dev/null && shellcheck ./install.sh ./bin/install ./bin/install.d/platform-tools ./bin/install.d/language-tools ./bin/sync ./bin/doctor ./bin/workbench || true
    ./bin/doctor

test:
    emacs --batch --no-init-file -L test -l ert -l test-helper \
      -l test/unit/test-core.el \
      -l test/unit/test-jira.el \
      -l test/unit/test-terminals.el \
      -l test/unit/test-git.el \
      -l test/unit/test-files.el \
      -l test/unit/test-coding.el \
      -l test/unit/test-session.el \
      -l test/unit/test-ai.el \
      -l test/unit/test-org.el \
      -l test/unit/test-dashboard.el \
      -l test/unit/test-mermaid.el \
      -l test/unit/test-bugs.el \
      -l test/unit/test-workflow-bugs.el \
      -l test/unit/test-repos.el \
      -l test/unit/test-repos-render.el \
      -l test/unit/test-visual.el \
      -l test/unit/test-command-centre.el \
      -l test/unit/test-interface.el \
      -f ert-run-tests-batch-and-exit

test-behaviour profile="work":
    ./test/run-behaviour-tests.sh {{profile}}

test-all:
    just test
    just test-behaviour work

workbench profile="personal":
    ./bin/workbench {{profile}}

personal:
    ./bin/workbench personal

work:
    ./bin/workbench work

stop profile="personal":
    ./bin/workbench stop {{profile}}

restart profile="personal":
    ./bin/workbench restart {{profile}}

restart-all:
    ./bin/workbench stop personal
    ./bin/workbench stop work

status:
    git status --short
