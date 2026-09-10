#!/bin/bash
set -euo pipefail

# shellcheck disable=SC1091
source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

if [ ! -f "${REPORT}" ]; then
  log_error "No lychee report at ${REPORT}."
  exit 1
fi

# The label is the lookup key, so it must name exactly one label, and every step must use the same spelling of it.
if [[ ${LABEL} == *,* || ${LABEL} == *$'\n'* ]]; then
  log_error 'The label input must name a single label.'
  exit 1
fi

normalized=$(split_labels "${LABEL}")
if [ -z "${normalized}" ]; then
  log_error 'The label input must not be empty.'
  exit 1
fi

write_output 'label' "${normalized}"
