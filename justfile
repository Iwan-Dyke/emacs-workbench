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
    -emacsclient --socket-name workbench-{{profile}} --eval '(kill-emacs)'

restart profile="personal":
    -emacsclient --socket-name workbench-{{profile}} --eval '(kill-emacs)'
    ./bin/workbench {{profile}}

restart-all:
    -emacsclient --socket-name workbench-personal --eval '(kill-emacs)'
    -emacsclient --socket-name workbench-work --eval '(kill-emacs)'

status:
    git status --short
