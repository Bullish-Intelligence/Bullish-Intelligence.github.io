#!/usr/bin/env bash
# Build the site and validate it: markdown lint (authored content) + broken-link
# check (rendered output). Runs BOTH checks even if the first fails, then exits
# non-zero if either reported a problem.
set -uo pipefail
# shellcheck source=../lib/common.sh
source "$SITEMAN_ROOT/lib/common.sh"
# shellcheck source=../lib/deploy.sh
source "$SITEMAN_ROOT/lib/deploy.sh"

# common.sh enables `set -e`; turn it back off so a markdown-lint failure doesn't
# abort the script before the link check (and vice versa) — we want every problem
# surfaced in one run.
set +e

usage() {
  cat <<'USAGE'
usage: siteman-check

Build the site and validate it: markdown lint and prose lint on content/, then
a broken-link check on the rendered publish directory (publishDir in
.siteman/hugo.toml), then the deploy workflow checks if the site has one.
Exit 0 when all checks pass, 1 when any check fails.
USAGE
}

case "${1:-}" in
  "") ;;
  -h | --help)
    usage
    exit 0
    ;;
  *)
    echo "siteman-check: unexpected argument '$1'" >&2
    usage >&2
    exit 3
    ;;
esac

root="$(siteman_find_root)" || exit 1
cd "$root" || exit 1

rc=0

if [ -d content ]; then
  echo "siteman: linting markdown…"
  markdownlint-cli2 --config .siteman/markdownlint.yaml "content/**/*.md" || rc=1
  echo "siteman: linting prose…"
  vale --config .siteman/vale.ini content || rc=1
else
  echo "siteman: no content/ directory — skipping markdown + prose lint"
fi

echo "siteman: building…"
# --cleanDestinationDir removes stale files from the publish dir so the link check runs
# against exactly the current site (e.g. a deleted page can't leave a dead link).
if ! { siteman_sync && siteman_hugo --gc --minify --cleanDestinationDir; }; then
  echo "siteman: build failed" >&2
  exit 1
fi

echo "siteman: checking links…"
# Pass the real publish directory. htmltest uses this path instead of the
# DirectoryPath in the config, so a custom publishDir needs no config edit.
if publish_path="$(siteman_publish_path)"; then
  htmltest -c .siteman/htmltest.yml "$publish_path" || rc=1
else
  echo "siteman: could not read publishDir from .siteman/hugo.toml" >&2
  rc=1
fi

# The deploy pass is silent when this site has no siteman-managed workflow.
siteman_deploy_check || rc=1

if [ "$rc" -eq 0 ]; then
  echo "siteman: all checks passed"
else
  echo "siteman: checks FAILED" >&2
fi
exit "$rc"
