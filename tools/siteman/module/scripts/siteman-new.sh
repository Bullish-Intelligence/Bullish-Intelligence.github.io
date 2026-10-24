#!/usr/bin/env bash
# Create a content file from an archetype. e.g. siteman-new posts/my-title
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$SITEMAN_ROOT/lib/common.sh"

usage() {
  cat <<'USAGE'
usage: siteman-new <path>

Create a content file from an archetype. The path is relative to content/ and
works from any directory inside the site. The .md suffix is optional.
example: siteman-new posts/my-title
USAGE
}

case "${1:-}" in
  -h | --help)
    usage
    exit 0
    ;;
  -*)
    echo "siteman-new: unknown option '$1'" >&2
    usage >&2
    exit 3
    ;;
  "")
    usage >&2
    exit 3
    ;;
esac

if [ "$#" -gt 1 ]; then
  echo "siteman-new: expected one path, got $#" >&2
  usage >&2
  exit 3
fi

target="$1"
case "$target" in
  *.md) ;;
  *) target="$target.md" ;;
esac

siteman_hugo new content "$target"
