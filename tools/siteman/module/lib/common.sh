#!/usr/bin/env bash
# Shared helpers sourced by every siteman-* script.
#
# Contract:
#   - SITEMAN_ROOT is exported by the devenv module and points at the shipped
#     module directory (containing scripts/, lib/, templates/).
#   - The "site root" is the consuming repo's root: the nearest ancestor of the
#     current directory that contains a .siteman/ folder.
#   - All Hugo invocations run from the site root with the hidden config.
set -euo pipefail

SITEMAN_CONFIG=".siteman/hugo.toml"

# Print the site root (nearest ancestor containing .siteman/), or fail.
siteman_find_root() {
  local dir="$PWD"
  while [ "$dir" != "/" ]; do
    if [ -d "$dir/.siteman" ]; then
      printf '%s\n' "$dir"
      return 0
    fi
    dir="$(dirname "$dir")"
  done
  echo "siteman: not inside a siteman site (no .siteman/ found). Run 'siteman-init'." >&2
  return 1
}

# Run Hugo from the site root with the hidden config injected. Hugo requires an
# absolute cache dir, so it is resolved from the (known) root here rather than
# via a relative env var.
siteman_hugo() {
  local root
  root="$(siteman_find_root)" || return 1
  (cd "$root" && HUGO_CACHEDIR="$root/.siteman/.cache" hugo --config "$SITEMAN_CONFIG" "$@")
}

# Print the publish directory exactly as Hugo reports it (relative to the site
# root, or absolute). Honors `publishDir` from .siteman/hugo.toml. Fails when
# Hugo cannot read the config.
siteman_publish_dir() {
  local json dir
  json="$(siteman_hugo config --format json 2>/dev/null)" || return 1
  dir="$(printf '%s\n' "$json" |
    sed -nE 's/^[[:space:]]*"publishdir":[[:space:]]*"([^"]*)",?$/\1/p' |
    head -n 1)"
  [ -n "$dir" ] || return 1
  printf '%s\n' "$dir"
}

# Print an absolute path with "." and ".." segments and extra slashes removed.
# Pure text: it does not touch the filesystem or follow symlinks.
siteman_normalize_path() {
  local part out="" IFS=/
  local -a parts=() stack=()
  read -r -a parts <<<"$1"
  for part in "${parts[@]}"; do
    case "$part" in
      "" | .) ;;
      ..) [ "${#stack[@]}" -eq 0 ] || unset 'stack[${#stack[@]}-1]' ;;
      *) stack+=("$part") ;;
    esac
  done
  for part in "${stack[@]}"; do
    out="$out/$part"
  done
  printf '%s\n' "${out:-/}"
}

# Print the publish directory as a normalized absolute path.
siteman_publish_path() {
  local root dir
  root="$(siteman_find_root)" || return 1
  dir="$(siteman_publish_dir)" || return 1
  case "$dir" in
    /*) ;;
    *) dir="$root/$dir" ;;
  esac
  siteman_normalize_path "$dir"
}

# Copy every file under $1 into $2, skipping files that already exist. Unlike
# `cp -rn`, this reports real copy errors: with `set -e`, a failed copy stops
# the script.
siteman_copy_missing() {
  local src="$1" dst="$2" rel
  while IFS= read -r -d '' rel; do
    mkdir -p "$dst/$(dirname "$rel")"
    if [ ! -e "$dst/$rel" ]; then
      cp "$src/$rel" "$dst/$rel"
    fi
  done < <(cd "$src" && find . -type f -print0)
}

# A stale `_vendor/` snapshot makes siteman_sync skip module work (see
# below). Hugo then fails on a theme the snapshot lacks, so warn when a remote
# module path in the config is missing from _vendor/modules.txt.
siteman_warn_stale_vendor() {
  local mod
  [ -f "_vendor/modules.txt" ] || return 0
  while IFS= read -r mod; do
    mod="${mod//\"/}"
    if ! grep -qF -- "$mod" "_vendor/modules.txt"; then
      echo "siteman: warning: '$mod' is in the config but not in _vendor/; run 'hugo mod vendor' to refresh the snapshot" >&2
    fi
  done < <(grep -v '^[[:space:]]*#' "$SITEMAN_CONFIG" 2>/dev/null |
    grep -Eo '"[a-z0-9-]+(\.[a-z0-9-]+)+/[^"]+"' || true)
}

# Resolve theme modules if the site declares any. Idempotent; safe to call as a
# preflight before serve/build. No-op unless a *remote* (domain-qualified) theme
# or import is declared. Runs in a subshell so the caller's directory is never
# changed, and stops on its own errors even when the caller disabled `set -e`.
siteman_sync() {
  local root
  root="$(siteman_find_root)" || return 1
  (
    cd "$root" || exit 1

    # Vendored themes win: if the site committed a `_vendor/` snapshot (via
    # `hugo mod vendor`), Hugo builds straight from it. Skip the network fetch
    # entirely so serve/build stay fully offline and deterministic. Refresh the
    # snapshot deliberately with `hugo mod vendor` when you want newer themes.
    # The snapshot does not track config edits, so a new theme needs a refresh;
    # siteman only warns about that, it does not re-vendor.
    if [ -d "_vendor" ]; then
      siteman_warn_stale_vendor
      exit 0
    fi

    # Only a remote theme needs Go modules. The shipped fallback theme is
    # `theme = ["siteman-default"]` — a bare, local themesDir name with no dot or
    # slash, so it never triggers module work. A domain-qualified path
    # (github.com/owner/repo, in a `theme` array entry or a `[[module.imports]]`
    # path) does. We look for a quoted "<host>.<tld>/<…>" token, which matches
    # those module paths but not local names, titles, or the scheme-prefixed
    # baseURL ("https://…" — the quote is followed by the scheme, not a bare host).
    # Comment lines are stripped first so the commented example in the shipped
    # template (a real github.com/... path) doesn't trigger a spurious sync.
    if ! grep -v '^[[:space:]]*#' "$SITEMAN_CONFIG" 2>/dev/null |
      grep -Eq '"[a-z0-9-]+(\.[a-z0-9-]+)+/[^"]+"'; then
      exit 0
    fi

    if [ ! -f "go.mod" ]; then
      modpath="$(git config --get remote.origin.url 2>/dev/null |
        sed -E 's#(\.git)?$##; s#.*[:/]([^/]+/[^/]+)$#github.com/\1#')"
      [ -n "$modpath" ] || modpath="example.com/site"
      siteman_hugo mod init "$modpath" || exit 1
    fi

    # `mod tidy` reconciles go.mod/go.sum with the imports declared in the config
    # (adding new themes, dropping removed ones) and downloads them. Avoid
    # `mod get ./...`, whose package arg makes Hugo forward our --config flag to
    # the underlying `go get` and error out.
    siteman_hugo mod tidy || exit 1
  )
}
