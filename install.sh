#!/usr/bin/env bash
set -u

repo_root="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
exec "$repo_root/bin/install" "$@"
