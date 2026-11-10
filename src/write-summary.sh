#!/bin/bash
set -euo pipefail

source "$(dirname "${BASH_SOURCE[0]}")/common.sh"

require_cmd jq

# GitHub rejects a step summary larger than 1 MiB, which a long list of links can reach.
summary_limit=1048576
summary_overhead=4096

jq --null-input --raw-output \
  --slurpfile records "${RECORDS}" \
  --rawfile reported "${REPORTED}" \
  --rawfile opened "${OPENED_ISSUES}" \
  --rawfile closed "${CLOSED_ISSUES}" \
  --arg issues "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/issues" \
  --argjson budget "$((summary_limit - summary_overhead))" '
  def pairs: split("\n") | map(select(length > 0) | split("\t") | {number: .[0], url: (.[1:] | join("\t"))});
  def by_url: map({key: .url, value: .number}) | from_entries;
  # A pipe splits a table cell even inside a code span, so it is escaped as well.
  # A backslash is replaced because one before a pipe would cancel that escape.
  def code: "`\(gsub("[`\\\\[:cntrl:]]"; "�") | gsub("\\|"; "\\|"))`";
  def issue_link: "[#\(.)](\($issues)/\(.))";
  def fit($lines; $budget):
    ([foreach $lines[] as $line (0; . + ($line | utf8bytelength) + 1)]) as $cumulative
    | ([$cumulative[] | select(. <= $budget)] | length) as $kept
    | {
        lines: $lines[:$kept],
        omitted: (($lines | length) - $kept),
        used: (if $kept > 0 then $cumulative[$kept - 1] else 0 end),
      };
  def table($header; $fitted):
    "",
    $header,
    ($header | gsub("[^|]+"; " --- ")),
    $fitted.lines[],
    (if $fitted.omitted > 0 then "", "and \($fitted.omitted) more." else empty end);

  ($reported | pairs | by_url) as $tracked
  | ($opened | pairs) as $opened_issues
  | ($opened_issues | by_url) as $new
  | ($closed | pairs) as $closed_issues
  | [
      $records[]
      | .url as $url
      | (if $new[$url] then "\($new[$url] | issue_link) (new)"
        elif $tracked[$url] then ($tracked[$url] | issue_link)
        else "None" end) as $issue
      | "| \($url | code) | \(.status | tostring | code) | \($issue) |"
    ] as $broken_rows
  | [$closed_issues[] | "| \(.url | code) | \(.number | issue_link) |"] as $closed_rows
  | fit($broken_rows; $budget) as $broken_fitted
  | fit($closed_rows; $budget - $broken_fitted.used) as $closed_fitted
  | "## Broken Links",
    "",
    "lychee found \($records | length) unreachable link(s). This run opened \($opened_issues | length) issue(s) and closed \($closed_issues | length).",
    (if ($broken_rows | length) > 0 then table("| Link | Status | Issue |"; $broken_fitted) else empty end),
    (if ($closed_rows | length) > 0 then "", "### Closed Issues", table("| Link | Issue |"; $closed_fitted) else empty end)
' >> "${GITHUB_STEP_SUMMARY}"
