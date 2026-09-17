#!/bin/bash
set -euo pipefail

log_warn() {
  echo "::warning::$*"
}

log_error() {
  echo "::error::$*"
}

require_cmd() {
  local cmd="$1"
  if ! command -v "${cmd}" >/dev/null 2>&1; then
    log_error "Required command not found: ${cmd}. Install it on the runner to use this action."
    exit 1
  fi
}

write_output() {
  local key="$1"
  local value="$2"
  echo "${key}=${value}" >>"${GITHUB_OUTPUT}"
}

# GitHub asks for at least a second between mutative requests, to stay clear of its secondary rate limit.
pace_mutation() {
  sleep 1
}

# `gh --label` parses its value as CSV, so a name carrying a quote or a comma has to be handed over as one CSV field.
csv_field() {
  local value="$1"
  printf '"%s"' "${value//\"/\"\"}"
}

split_labels() {
  local raw="$1"
  local -a names
  local name

  # `read` stops at the first line, so a line break has to become a separator first.
  IFS=',' read -ra names <<<"${raw//$'\n'/,}"
  for name in "${names[@]}"; do
    # Only the padding around a name is dropped: 'help wanted' is a single label, not two.
    name="${name#"${name%%[![:space:]]*}"}"
    name="${name%"${name##*[![:space:]]}"}"
    if [ -n "${name}" ]; then
      printf '%s\n' "${name}"
    fi
  done
}
