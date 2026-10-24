#!/usr/bin/env bash
# GitHub Pages workflow scaffolding and validation.

siteman_deploy_scaffold() {
  local root="$1"
  local force="${2:-0}"
  local workflow sidecar template marker first_line

  workflow="$root/.github/workflows/siteman-deploy-github-pages.yml"
  sidecar="$workflow.siteman-new"
  template="$SITEMAN_ROOT/templates/deploy/github-pages.yml"
  marker="# siteman-managed: deploy/github-pages v1"

  mkdir -p "$(dirname "$workflow")"

  if [ ! -e "$workflow" ]; then
    cp "$template" "$workflow"
    chmod u+w "$workflow"
    echo "siteman: created $workflow"
    return 0
  fi

  first_line="$(head -n 1 "$workflow")"
  if [ "$first_line" != "$marker" ]; then
    echo "siteman: workflow is user-owned (marker missing); leaving it unchanged"
    return 0
  fi

  if cmp -s "$template" "$workflow"; then
    echo "siteman: workflow already current"
    return 0
  fi

  if [ "$force" -eq 1 ]; then
    chmod u+w "$workflow"
    cp "$template" "$workflow"
    chmod u+w "$workflow"
    rm -f "$sidecar"
    echo "siteman: restored the managed workflow from the template"
    return 0
  fi

  if [ -e "$sidecar" ]; then
    chmod u+w "$sidecar" 2>/dev/null || true
  fi
  cp "$template" "$sidecar"
  chmod u+w "$sidecar"
  echo "siteman: workflow drift detected; kept your file and wrote $sidecar"
}

siteman_deploy_normalize_path() {
  local path="$1"
  path="${path#./}"
  while [ "${path%/}" != "$path" ]; do
    path="${path%/}"
  done
  printf '%s\n' "$path"
}

siteman_deploy_check() {
  local root workflow rc=0 publish_dir artifact_path normalized_publish normalized_artifact
  local -a workflows

  root="$(siteman_find_root)" || return 1
  shopt -s nullglob
  workflows=("$root"/.github/workflows/siteman-deploy-*.yml)
  shopt -u nullglob
  [ "${#workflows[@]}" -gt 0 ] || return 0

  echo "siteman: checking deploy workflows…"

  for workflow in "${workflows[@]}"; do
    echo "  $(basename "$workflow")"

    if actionlint "$workflow"; then
      echo "    actionlint passed"
    else
      echo "    FAIL: actionlint reported a workflow error" >&2
      rc=1
    fi

    if publish_dir="$(siteman_publish_dir)"; then
      artifact_path="$(awk '
        /uses:[[:space:]]*actions\/upload-pages-artifact@/ { in_upload = 1; next }
        in_upload && /^[[:space:]]*-[[:space:]]/ { exit }
        in_upload && /^[[:space:]]*path:[[:space:]]*/ {
          sub(/^[[:space:]]*path:[[:space:]]*/, "")
          gsub(/^"|"$/, "")
          print
          exit
        }
      ' "$workflow")"

      normalized_publish="$(siteman_deploy_normalize_path "$publish_dir")"
      normalized_artifact="$(siteman_deploy_normalize_path "$artifact_path")"
      if [ -n "$normalized_publish" ] && [ "$normalized_artifact" = "$normalized_publish" ]; then
        echo "    artifact path matches publishDir ($normalized_publish)"
      else
        echo "    FAIL: artifact path '$artifact_path' does not match publishDir '$publish_dir'" >&2
        rc=1
      fi
    else
      echo "    FAIL: Hugo could not read publishDir from .siteman/hugo.toml" >&2
      rc=1
    fi

    if awk '/run:/ && /siteman-build/ && /--baseURL/ && /steps\.pages\.outputs\.base_url/ { found = 1 }
      END { exit !found }' "$workflow"; then
      echo "    baseURL uses configure-pages output"
    else
      echo "    FAIL: build must pass configure-pages base_url to --baseURL" >&2
      rc=1
    fi

    for permission in 'contents:[[:space:]]*read' 'pages:[[:space:]]*write' 'id-token:[[:space:]]*write'; do
      if grep -Eq "^[[:space:]]+${permission}[[:space:]]*$" "$workflow"; then
        :
      else
        echo "    FAIL: required permission is missing: ${permission%%:*}" >&2
        rc=1
      fi
    done

    if grep -Eq '^[[:space:]]+cancel-in-progress:[[:space:]]*false[[:space:]]*$' "$workflow"; then
      echo "    deploy concurrency does not cancel in-flight publishes"
    else
      echo "    FAIL: cancel-in-progress must be false" >&2
      rc=1
    fi

    if grep -Eq '^[[:space:]]+include-hidden-files:[[:space:]]*true[[:space:]]*$' "$workflow"; then
      echo "    upload includes hidden files"
    else
      echo "    FAIL: upload must include hidden files" >&2
      rc=1
    fi
  done

  if git -C "$root" check-ignore --no-index -q -- devenv.lock 2>/dev/null; then
    echo "siteman: warning: devenv.lock is ignored; commit it so CI uses the pinned toolchain" >&2
  elif ! git -C "$root" ls-files --error-unmatch -- devenv.lock >/dev/null 2>&1; then
    echo "siteman: warning: devenv.lock is not tracked; commit it so CI uses the pinned toolchain" >&2
  fi

  if [ -f "$root/static/CNAME" ]; then
    echo "siteman: warning: static/CNAME is ignored by this Pages workflow; set a custom domain in GitHub" >&2
  fi
  if [ -f "$root/static/.nojekyll" ]; then
    echo "siteman: warning: static/.nojekyll is not needed by this Pages workflow" >&2
  fi

  echo "siteman: confirm Settings → Pages → Build and deployment → Source is GitHub Actions"
  return "$rc"
}
