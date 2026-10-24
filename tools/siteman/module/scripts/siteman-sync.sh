#!/usr/bin/env bash
# Resolve/fetch theme modules declared in .siteman/hugo.toml. Idempotent.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$SITEMAN_ROOT/lib/common.sh"

usage() {
  cat <<'USAGE'
usage: siteman-sync

Fetch the remote theme modules named in .siteman/hugo.toml. Do nothing when
the site uses only local themes or has a committed _vendor/ snapshot.
USAGE
}

case "${1:-}" in
  "") ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "siteman-sync: unexpected argument '$1'" >&2
    usage >&2
    exit 3
    ;;
esac

siteman_sync
