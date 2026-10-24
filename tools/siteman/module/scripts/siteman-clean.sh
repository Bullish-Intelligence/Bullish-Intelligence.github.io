#!/usr/bin/env bash
# Remove build output and caches. Leaves config and content untouched.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$SITEMAN_ROOT/lib/common.sh"

usage() {
  cat <<'USAGE'
usage: siteman-clean

Remove the publish directory (publishDir in .siteman/hugo.toml, "public" by
default), the Hugo resource cache, and the module cache. Config and content stay.
USAGE
}

case "${1:-}" in
  "") ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "siteman-clean: unexpected argument '$1'" >&2
    usage >&2
    exit 3
    ;;
esac

root="$(siteman_find_root)"

# Resolve the real publish directory. If Hugo cannot read the config (for
# example, a broken theme), fall back to the default so clean still works.
if ! pub="$(siteman_publish_path)"; then
  echo "siteman: could not read publishDir; assuming 'public'" >&2
  pub="$root/public"
fi

# Remove only a directory strictly inside the site root. Never remove the root
# itself or anything outside it, even if publishDir points there.
publish_targets=()
case "$pub" in
  "$root"/?*) publish_targets=("$pub") ;;
  *) echo "siteman: publishDir '$pub' is not inside the site root; not removing it" >&2 ;;
esac

# Go's module cache (.siteman/.cache) is written read-only; make it removable.
chmod -R u+w "$root/.siteman/.cache" 2>/dev/null || true
rm -rf "${publish_targets[@]}" "$root/.siteman/resources" "$root/.siteman/.cache" \
  "$root/.hugo_build.lock"
echo "siteman: cleaned build output and caches."
