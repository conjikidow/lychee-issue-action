#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

records=$(mktemp)
jq -c --arg prefix "file://${GITHUB_WORKSPACE}/" '
  [
    ((.error_map // {}), (.timeout_map // {})) | to_entries[] | .key as $file | .value[] | {
      url: (.url | if startswith($prefix) then ltrimstr($prefix) else . end),
      status: .status.text,
      ref: "\($file):\(.span.line // "?")",
    }
  ]
  | group_by(.url)
  | map({url: .[0].url, status: .[0].status, refs: (map(.ref) | unique)})
  | .[]
' "${REPORT}" >"${records}"

write_output 'records' "${records}"
write_output 'broken' "$(wc -l <"${records}" | tr -d '[:space:]')"
