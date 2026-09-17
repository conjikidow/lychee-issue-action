# Lychee Issue Action

[![Marketplace](https://img.shields.io/badge/Marketplace-Lychee_Issue_Action-2088FF.svg?style=flat&logo=githubactions&logoColor=white)](https://github.com/marketplace/actions/lychee-issue-action)
[![Release](https://img.shields.io/github/v/release/conjikidow/lychee-issue-action?style=flat&logo=github&logoColor=white&label=release)](https://github.com/conjikidow/lychee-issue-action/releases/latest)
[![License](https://img.shields.io/badge/license-MIT%20OR%20Apache--2.0-blue.svg?style=flat)](#license)
[![prek](https://img.shields.io/endpoint?url=https://raw.githubusercontent.com/j178/prek/master/docs/assets/badge-v0.json)](https://github.com/j178/prek)
[![CI](https://github.com/conjikidow/lychee-issue-action/actions/workflows/ci.yaml/badge.svg)](https://github.com/conjikidow/lychee-issue-action/actions/workflows/ci.yaml)

A GitHub Action to track the broken links found by [lychee](https://github.com/lycheeverse/lychee) as GitHub issues.

> [!WARNING]
> This project is in early development. The API may change in future releases.

## Features

- Opens one issue per unreachable link, listing the locations that reference it.
- Closes an issue as soon as its link is reachable again.
- Recognizes the issues it opened in earlier runs, so a recurring break does not pile up duplicates.

## Usage

The action requires `gh` and `jq`, which the GitHub-hosted runner images provide.

### Workflow Example

The link check itself is left to [`lychee-action`](https://github.com/lycheeverse/lychee-action),
which writes the report this action reads.
The following workflow checks the links every Monday and keeps one issue open per unreachable link.

```yaml
name: Link Check

on:
  schedule:
    - cron: '0 0 * * 1'
  workflow_dispatch:

concurrency:
  group: ${{ github.workflow }}

jobs:
  link-check:
    runs-on: ubuntu-latest
    permissions:
      contents: read
      issues: write

    steps:
      - name: Checkout the repository
        uses: actions/checkout@v7
        with:
          persist-credentials: false

      - name: Check the links
        uses: lycheeverse/lychee-action@v2
        with:
          format: json
          output: lychee/out.json
          fail: false

      - name: Sync the issues with the report
        uses: conjikidow/lychee-issue-action@v0.2.0
```

Three of the `lychee-action` inputs above are not optional for this setup.
`format: json` produces the machine-readable report this action reads, instead of the Markdown summary.
`output: lychee/out.json` matches this action's `report` default; lychee-action otherwise writes `lychee/out.md`.
`fail: false` keeps lychee from failing the job on broken links, which would stop this action from ever running.

The `concurrency` group serializes the runs: two overlapping runs would both see the same set of open issues,
and both would open an issue for the same link.

The example references actions by tag for readability.
For production workflows, consider pinning each action to a full-length commit SHA,
as [GitHub recommends](https://docs.github.com/en/actions/reference/security/secure-use#using-third-party-actions).
Releases of this action are immutable, so its own tags are already locked to a single commit.

### Permissions

The token passed to `github-token` needs `issues: write` to open and close the issues,
and to create the labels it applies.

The default `${{ github.token }}` carries whatever the workflow grants it,
so grant that scope in the job, as the example above does.
The `contents: read` there is for the checkout step, not for this action.

The `permissions:` block does not reach a token you pass yourself.
A GitHub App installation token needs the same access granted to the app itself.

### Inputs

| Name           | Description                                                                     | Required | Default                   |
| -------------- | ------------------------------------------------------------------------------- | -------- | ------------------------- |
| `report`       | Path to the report lychee wrote with `--format json`.                           | No       | `'lychee/out.json'`       |
| `label`        | Label carried by every issue the action opens, and the key it looks them up by. | No       | `'links'`                 |
| `extra-labels` | Further labels to apply on creation, separated by commas. Not used for lookup.  | No       | `''`                      |
| `title-prefix` | Text placed before the link in the issue title.                                 | No       | `'docs: fix broken link'` |
| `github-token` | Token used to authenticate with GitHub.                                         | No       | `${{ github.token }}`     |

### Outputs

| Name      | Description                                |
| --------- | ------------------------------------------ |
| `broken`  | Number of unreachable links in the report. |
| `created` | Number of issues opened by this run.       |
| `closed`  | Number of issues closed by this run.       |

### Labels

`label` is applied to every issue the action opens, and it is also the key the action looks its own issues up by.
`extra-labels` is applied on creation only and plays no part in the lookup.
Being the key, `label` names a single label: surrounding whitespace is trimmed, and a value containing a comma is rejected.

Any of these labels that the repository does not define yet is created before the first issue is opened,
because `gh issue create` rejects a label that does not exist.
Define them in the repository beforehand if you do not want the action to create them.

> [!IMPORTANT]
> Changing `label` after the first run hides the issues opened under the previous one.
> They are no longer closed when their links recover, and a second issue is opened for every link still broken.
> Changing `extra-labels` affects newly opened issues only.

## How It Works

1. Reads the lychee report, grouping the failed and timed-out links by URL with every location that references them.
2. Lists the open issues carrying `label`, and reads the `<!-- lychee: <url> -->` marker from each body.
3. Opens an issue for every unreachable link that has no issue yet.
4. Closes the issues whose links no longer appear in the report.

> [!NOTE]
> The marker in the issue body is what pairs an issue with a link.
> Removing it from a body makes the action treat that link as unreported and open a second issue.
> A closed issue is never reopened either: when a link breaks again, the action opens a new issue for it.

## License

Licensed under either of [MIT license](LICENSE-MIT) or [Apache License, Version 2.0](LICENSE-APACHE) at your option.

Unless you explicitly state otherwise, any contribution intentionally submitted for inclusion in this software
by you, as defined in the Apache-2.0 license, shall be dually licensed as above,
without any additional terms or conditions.

## Contributing & Feedback

Contributions, bug reports, and feedback are always welcome!
Thank you for helping improve this project for everyone!
