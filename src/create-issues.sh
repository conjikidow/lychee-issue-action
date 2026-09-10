#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

label_args=()
while IFS= read -r name <&3; do
  label_args+=(--label "$(csv_field "${name}")")
done 3< <(split_labels "${LABEL},${EXTRA_LABELS}")

# An issue outlives the run that opened it, so the link has to stay useful after that run.
workflow=${GITHUB_WORKFLOW_REF%%@*}
report_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/workflows/${workflow##*/}"

reported_urls=$(mktemp)
cut -f2 "${REPORTED}" >"${reported_urls}"

# GitHub rejects a body longer than 65536 characters, and a link referenced everywhere would reach it.
refs_limit=50

write_body() {
  local record=$1
  local url=$2

  printf 'A link check found this link to be unreachable.\n\n'
  printf -- '- URL: %s\n' "${url}"
  printf -- '- Status: %s\n\n' "$(jq -r '.status' <<<"${record}")"
  printf 'Referenced from:\n\n'
  jq -r --argjson limit "${refs_limit}" '.refs[:$limit][] | "- `\(.)`"' <<<"${record}"

  local omitted
  omitted=$(jq -r --argjson limit "${refs_limit}" '(.refs | length) - $limit | if . > 0 then . else 0 end' <<<"${record}")
  if [ "${omitted}" -gt 0 ]; then
    printf '\nand %s more.\n' "${omitted}"
  fi
  printf '\nSee the [workflow runs](%s) for the latest report.\n' "${report_url}"
  printf '\n<!-- lychee: %s -->\n' "${url}"
}

created=0
# The records are read on a dedicated descriptor so that gh keeps its own stdin.
while IFS= read -r record <&3; do
  url=$(jq -r '.url' <<<"${record}")
  if grep -qxF -- "${url}" "${reported_urls}"; then
    continue
  fi

  body=$(mktemp)
  write_body "${record}" "${url}" >"${body}"
  # GitHub rejects a title longer than 256 characters.
  title="${TITLE_PREFIX} ${url}"
  if [ "${#title}" -gt 256 ]; then
    title="${title:0:253}..."
  fi

  gh issue create --title "${title}" --body-file "${body}" "${label_args[@]}"
  created=$((created + 1))
  pace_mutation
done 3<"${RECORDS}"

write_output 'created' "${created}"
