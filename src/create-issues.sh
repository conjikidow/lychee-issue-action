#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

label_args=()
while IFS= read -r name <&3; do
  label_args+=(--label "$(csv_field "${name}")")
done 3< <(split_labels "${LABEL},${EXTRA_LABELS}")

workflow=${GITHUB_WORKFLOW_REF%%@*}
report_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/actions/workflows/${workflow##*/}"

blob_url="${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/blob/${GITHUB_SHA}"

reported_urls=$(mktemp)
cut -f2 "${REPORTED}" >"${reported_urls}"

substitute=$(printf '\xEF\xBF\xBD')
autolink_pattern='^[a-zA-Z][a-zA-Z0-9+.-]{1,31}://[^[:space:][:cntrl:]<>]+$'

# GitHub rejects a body longer than 65536 characters, which a link referenced from long paths can reach.
body_limit=65536
body_overhead=1024
refs_limit=20

write_body() {
  local record=$1
  local url=$2
  local status=$3
  local budget=$4

  local link
  if [[ ${url} =~ ${autolink_pattern} ]]; then
    link="<${url}>"
  else
    link="\`${url//\`/${substitute}}\`"
  fi

  local present
  present=$(jq -r --argjson limit "${refs_limit}" '[.refs[:$limit][].file] | unique[]' <<<"${record}" |
    while IFS= read -r file; do
      if [ "$(git -C "${GITHUB_WORKSPACE}" cat-file -t "${GITHUB_SHA}:${file}" 2>/dev/null)" = 'blob' ]; then
        printf '%s\n' "${file}"
      fi
    done | jq -Rn '[inputs]')

  printf 'A link check with [lychee](https://github.com/lycheeverse/lychee) found this link to be unreachable.\n\n'
  printf '**Link:** %s\n' "${link}"
  printf '**Status:** %s\n\n' "\`${status//\`/${substitute}}\`"
  printf '**Referenced from:**\n\n'
  jq -r --argjson limit "${refs_limit}" --argjson budget "${budget}" --argjson present "${present}" --arg blob "${blob_url}" '
    [
      .refs[:$limit][]
      | .file as $file
      | ($file | gsub("[`[:cntrl:]]"; "\uFFFD")) as $name
      | (if .line then "\($name):\(.line)" else "\($name):?" end) as $text
      | if ($present | index($file)) == null then
          "- `\($text)`"
        else
          ($file | split("/") | map(@uri | gsub("\\("; "%28") | gsub("\\)"; "%29")) | join("/")) as $path
          | (if .line then "#L\(.line)" else "" end) as $fragment
          | "- [`\($text)`](\($blob)/\($path)\($fragment))"
        end
    ] as $lines
    | ([foreach $lines[] as $line (0; . + ($line | length) + 1)]) as $cumulative
    | ([$cumulative[] | select(. <= $budget)] | length) as $kept
    | ((.refs | length) - $kept) as $omitted
    | $lines[:$kept][],
      (if $omitted > 0 then "\nand \($omitted) more." else empty end)
  ' <<<"${record}"
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

  status=$(jq -r '.status | tostring' <<<"${record}")
  budget=$(jq -r --argjson limit "${body_limit}" --argjson overhead "${body_overhead}" \
    '$limit - $overhead - 2 * (.url | tostring | length) - (.status | tostring | length)' <<<"${record}")
  if [ "${budget}" -le 0 ]; then
    log_warn "No issue opened for ${url}: it does not fit in an issue body."
    continue
  fi

  body=$(mktemp)
  write_body "${record}" "${url}" "${status}" "${budget}" >"${body}"
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
