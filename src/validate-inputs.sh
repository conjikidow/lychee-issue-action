#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd jq

if [[ ! -f ${REPORT} ]]; then
  log_error "No lychee report at ${REPORT}."
  exit 1
fi

# Every issue whose link is missing from the report gets closed, so a report from a failed or misconfigured run must stop here.
# lychee-action leaves an empty file behind when lychee exits without writing a report.
if [[ ! -s ${REPORT} ]]; then
  log_error "The lychee report at ${REPORT} is empty, so lychee probably failed before writing it."
  exit 1
fi

if ! jq --slurp --exit-status 'length == 1 and (.[0] | type == "object" and (.total | type) == "number")' "${REPORT}" > /dev/null; then
  log_error "The lychee report at ${REPORT} was not written with --format json."
  exit 1
fi

if ! jq --exit-status '.total > 0' "${REPORT}" > /dev/null; then
  log_error "The lychee report at ${REPORT} lists no links. This usually indicates a configuration error."
  exit 1
fi

# The label is the lookup key, so it must name exactly one label, and every step must use the same spelling of it.
if [[ ${LABEL} == *,* || ${LABEL} == *$'\n'* ]]; then
  log_error 'The label input must name a single label.'
  exit 1
fi

normalized="$(split_labels "${LABEL}")"
if [[ -z ${normalized} ]]; then
  log_error 'The label input must not be empty.'
  exit 1
fi

write_output 'label' "${normalized}"
