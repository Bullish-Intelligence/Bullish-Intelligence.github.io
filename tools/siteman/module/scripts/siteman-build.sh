#!/usr/bin/env bash
# Production build into the publish directory. Extra args pass through to `hugo`.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$SITEMAN_ROOT/lib/common.sh"

usage() {
  cat <<'USAGE'
usage: siteman-build [HUGO_FLAGS...]

Build the site for production (--gc --minify) into the publish directory
(publishDir in .siteman/hugo.toml, "public" by default). Any extra flags
pass through to hugo, e.g. siteman-build --baseURL https://example.com/.
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
esac

siteman_sync
siteman_hugo --gc --minify "$@"

root="$(siteman_find_root)"
if pub="$(siteman_publish_path)"; then
  case "$pub" in
    "$root"/*) pub="./${pub#"$root"/}" ;;
  esac
  echo "siteman: built into $pub"
else
  echo "siteman: built."
fi
