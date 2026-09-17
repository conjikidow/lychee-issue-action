#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd gh
require_cmd jq

broken_urls=$(mktemp)
jq -r '.url' "${RECORDS}" >"${broken_urls}"

closed=0
# The issues are read on a dedicated descriptor so that gh keeps its own stdin.
while IFS=$'\t' read -r number url <&3; do
  if grep -qxF -- "${url}" "${broken_urls}"; then
    continue
  fi

  gh issue close "${number}" --comment 'This link is reachable again.'
  closed=$((closed + 1))
  pace_mutation
done 3<"${REPORTED}"

write_output 'closed' "${closed}"
