#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd gh

limit=1000

existing="$(mktemp)"
gh label list --limit "${limit}" --json name --jq '.[].name' >"${existing}"

if [ "$(wc -l <"${existing}")" -ge "${limit}" ]; then
  log_warn "The repository defines more than ${limit} labels, so a label past that is taken to be missing."
fi

while IFS= read -r name <&3; do
  # GitHub treats label names as unique regardless of case.
  if grep -qixF -- "${name}" "${existing}"; then
    continue
  fi

  gh label create -- "${name}"
  pace_mutation
  # A name repeated across the inputs must not be created twice.
  printf '%s\n' "${name}" >>"${existing}"
done 3< <(split_labels "${LABEL},${EXTRA_LABELS}")
