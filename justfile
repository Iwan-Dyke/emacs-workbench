default:
    just --list

install:
    ./bin/install

sync:
    ./bin/sync

doctor:
    ./bin/doctor

check:
    bash -n ./bin/install ./bin/sync ./bin/doctor ./bin/workbench
    ./bin/doctor

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
