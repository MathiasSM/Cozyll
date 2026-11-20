#!/usr/bin/env bash
# Keep a single "Outdated Cabal dependencies" issue in sync with cabal outdated.
#
# Idempotent by design: the issue is identified by title (falling back to the
# label, so a rename does not open a new one), same-titled duplicates are
# closed as duplicates of the oldest issue, and state/body only change when
# they actually differ. The workflow also serialises runs through a concurrency
# group; the two defences are independent.
set -euo pipefail

TITLE="Outdated Cabal dependencies"
LABEL="automation/outdated"
LABEL_COLOR="d93f0b" # keep in sync with .github/labels.yaml

tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
report="$tmp/report.txt"

gh label create "$LABEL" --color "$LABEL_COLOR" \
  --description "Automated issue tracking outdated Cabal dependencies" \
  --force >/dev/null

cabal update
set +e
cabal outdated --exit-code >"$report" 2>&1
status=$?
set -e
cat "$report"

# cabal exits 1 both when packages are outdated and when the check itself
# fails, so classify on the report text: a failure must fail the job instead of
# being pasted into the issue body.
if [ "$status" -eq 0 ]; then
  outdated=false
elif grep -q '^Outdated dependencies:' "$report"; then
  outdated=true
else
  echo "::error::cabal outdated did not produce a dependency report (exit $status)"
  exit "$status"
fi

# Issues owned by this automation, sorted client-side because gh orders a
# --label listing by search relevance, not creation. Issue numbers grow with
# creation order, so the lowest number is the stable canonical pick. The
# assignment is deliberate: a failed lookup aborts the run under set -e
# instead of looking like "no issue exists" and opening a second one.
issues="$(gh issue list --label "$LABEL" --state all --limit 100 \
  --json number,title \
  --jq 'sort_by(.number) | .[] | "\(.number)\t\(.title)"')"
if [ -n "$issues" ]; then
  mapfile -t rows <<<"$issues"
else
  rows=()
fi

canonical=""
fallback=""
for row in "${rows[@]}"; do
  number="${row%%$'\t'*}"
  title="${row#*$'\t'}"
  if [ -z "$fallback" ]; then
    fallback="$number"
  fi
  if [ -z "$canonical" ] && [ "$title" = "$TITLE" ]; then
    canonical="$number"
  fi
done
if [ -z "$canonical" ]; then
  canonical="$fallback"
fi

# Collapse historical duplicates. Only same-titled issues are closed, so a
# maintainer reusing the label for something else is left alone.
if [ -n "$canonical" ]; then
  for row in "${rows[@]}"; do
    number="${row%%$'\t'*}"
    title="${row#*$'\t'}"
    if [ "$number" = "$canonical" ] || [ "$title" != "$TITLE" ]; then
      continue
    fi
    echo "Closing duplicate #$number (canonical: #$canonical)"
    gh issue close "$number" --duplicate-of "$canonical" \
      --comment "Duplicate of #$canonical: the dependency automation keeps a single issue."
  done
fi

state=""
current_body=""
if [ -n "$canonical" ]; then
  state="$(gh issue view "$canonical" --json state --jq .state)"
  current_body="$(gh issue view "$canonical" --json body --jq .body)"
fi

if [ "$outdated" = false ]; then
  if [ -n "$canonical" ] && [ "${state,,}" = "open" ]; then
    gh issue close "$canonical" --reason completed \
      --comment "All Cabal dependencies are up to date."
  fi
  exit 0
fi

if [ -z "$canonical" ]; then
  gh issue create --title "$TITLE" --label "$LABEL" --body-file "$report"
  exit 0
fi

if [ "${state,,}" = "closed" ]; then
  gh issue reopen "$canonical"
fi
gh issue edit "$canonical" --add-label "$LABEL" >/dev/null
if [ "$current_body" != "$(cat "$report")" ]; then
  gh issue edit "$canonical" --body-file "$report"
fi
