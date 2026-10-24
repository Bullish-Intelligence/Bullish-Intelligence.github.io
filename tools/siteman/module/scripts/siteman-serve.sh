#!/usr/bin/env bash
# Start the live-reload dev server. Extra args pass through to `hugo server`.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$SITEMAN_ROOT/lib/common.sh"

usage() {
  cat <<'USAGE'
usage: siteman-serve [HUGO_SERVER_FLAGS...]

Start the live-reload dev server with drafts and future posts shown. Any extra
flags pass through to `hugo server`, e.g. siteman-serve --port 1314.
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

siteman_sync
siteman_hugo server --buildDrafts --buildFuture "$@"
