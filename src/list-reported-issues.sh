#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd gh
require_cmd jq

limit=1000

listing=$(mktemp)
gh issue list --label "$(csv_field "${LABEL}")" --state open --limit "${limit}" --json number,body >"${listing}"

if [ "$(jq 'length' "${listing}")" -ge "${limit}" ]; then
  log_warn "More than ${limit} open issues carry the '${LABEL}' label, so the ones past that are ignored."
fi

# The action writes its marker at the end of the body, so the last one wins.
reported=$(mktemp)
jq -r '.[]
  | [.number, ([.body | scan("<!-- lychee: (.*?) -->")] | last | .[0]? // empty | gsub("^\\s+|\\s+$"; ""))]
  | select(length == 2 and (.[1] | length > 0))
  | "\(.[0])\t\(.[1])"' "${listing}" >"${reported}"

write_output 'reported' "${reported}"
