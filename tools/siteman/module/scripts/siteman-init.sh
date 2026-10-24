#!/usr/bin/env bash
# Scaffold a new siteman site in the current directory. Cold-start command.
set -euo pipefail
# shellcheck source=../lib/common.sh
source "$SITEMAN_ROOT/lib/common.sh"
# shellcheck source=../lib/deploy.sh
source "$SITEMAN_ROOT/lib/deploy.sh"

root="$PWD"
force=0
deploy_target=""

usage() {
  cat <<'USAGE'
usage: siteman-init [--force] [--deploy=github-pages | --deploy github-pages]

Scaffold a siteman site in the current directory.

  --force          Refresh an existing site's config. Also allows a new site
                   inside a directory that already belongs to a parent site.
  --deploy TARGET  Scaffold only the deploy workflow. Supported: github-pages.
  -h, --help       Show this text.
USAGE
}

usage_error() {
  usage >&2
  exit 3
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -h | --help)
      usage
      exit 0
      ;;
    --force)
      force=1
      ;;
    --deploy=*)
      deploy_target="${1#--deploy=}"
      [ -n "$deploy_target" ] || usage_error
      ;;
    --deploy)
      shift
      [ "$#" -gt 0 ] || usage_error
      deploy_target="$1"
      ;;
    *)
      echo "siteman-init: unknown argument '$1'" >&2
      usage_error
      ;;
  esac
  shift
done

if [ -n "$deploy_target" ] && [ "$deploy_target" != "github-pages" ]; then
  echo "siteman: unsupported deploy target '$deploy_target' (supported: github-pages)" >&2
  exit 3
fi

# Refuse to start a nested site inside a directory that already belongs to a
# site. Without this guard, init in a subdirectory would silently create a second
# .siteman/ there. --force is the explicit opt-in. A .siteman/ in $PWD itself is
# handled below (re-init).
if [ ! -d "$root/.siteman" ] && [ "$force" -ne 1 ]; then
  if parent_site="$(cd .. && siteman_find_root 2>/dev/null)"; then
    echo "siteman: $parent_site is already a siteman site." >&2
    echo "  Run siteman-init there, or pass --force to create a nested site here." >&2
    exit 1
  fi
fi

if [ -n "$deploy_target" ]; then
  siteman_deploy_scaffold "$root" "$force"
  exit 0
fi

if [ -d "$root/.siteman" ] && [ "$force" -ne 1 ]; then
  echo "siteman: .siteman/ already exists (use --force to refresh config)." >&2
  exit 1
fi

mkdir -p \
  "$root/.siteman/layouts" \
  "$root/.siteman/archetypes" \
  "$root/.siteman/themes" \
  "$root/.siteman/styles" \
  "$root/content/posts" \
  "$root/static" \
  "$root/assets"

# Site config: refresh only on --force so author edits are never clobbered.
if [ ! -f "$root/.siteman/hugo.toml" ] || [ "$force" -eq 1 ]; then
  cp "$SITEMAN_ROOT/templates/hugo.toml" "$root/.siteman/hugo.toml"
fi

# siteman-check config (links + markdown + prose lint). User-editable like
# hugo.toml, so copy only when missing — never clobber edits, even on --force.
for cfg in htmltest.yml markdownlint.yaml vale.ini; do
  [ -f "$root/.siteman/$cfg" ] || cp "$SITEMAN_ROOT/templates/$cfg" "$root/.siteman/$cfg"
done

# Shipped fallback theme: renders the whole site out of the box and falls back
# behind any theme the user adds. Copy without overwriting so edits survive a
# re-init. .siteman/layouts/ stays EMPTY — it is for project overrides only, and
# a theme (incl. siteman-default) now supplies the actual layouts.
# siteman_copy_missing skips existing files but still reports real copy errors.
siteman_copy_missing "$SITEMAN_ROOT/templates/theme/siteman-default" "$root/.siteman/themes/siteman-default"
siteman_copy_missing "$SITEMAN_ROOT/templates/archetypes" "$root/.siteman/archetypes"

# Example content only when the file is missing (never overwrite author content).
if [ ! -f "$root/content/posts/hello-world.md" ]; then
  cp "$SITEMAN_ROOT/templates/content/posts/hello-world.md" \
    "$root/content/posts/hello-world.md"
fi

# Files copied from the Nix store inherit its read-only permissions; make the
# scaffolded files writable so they can be edited and overridden.
chmod -R u+w "$root/.siteman" "$root/content"

# Append .gitignore entries that aren't already present.
touch "$root/.gitignore"
while IFS= read -r line; do
  [ -z "$line" ] && continue
  grep -qxF "$line" "$root/.gitignore" || printf '%s\n' "$line" >>"$root/.gitignore"
done <"$SITEMAN_ROOT/templates/gitignore.snippet"

echo "siteman: initialized."
echo "  - edit .siteman/hugo.toml to configure the site"
echo "  - add posts with:  siteman-new posts/my-title"
echo "  - preview with:    siteman-serve"
