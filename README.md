## Brakeman results parser github action

Brakeman is a static analysis tool which checks Ruby on Rails applications for security vulnerabilities.

You can read more about Brakeman itself [here](https://github.com/presidentbeef/brakeman).

This action helps make sure that brakeman results get accurately added to pull requests, in the event of a new issue.

Currently we recommend hardcoding the brakeman version (e.g. 8.1.1) to prevent the unintended consequences of pulling down the latest version
regardless of context.

## What it does

- Creates a "Brakeman" check run on the commit and adds an annotation for each warning. The check fails if Brakeman reports any security warnings and succeeds otherwise.
- When the triggering event has a pull request (`pull_request`, `pull_request_target`, `pull_request_review`, etc.), also posts a review comment for each warning in a file changed by the PR (for PRs with 3,000 or more changed files, GitHub can't list them all, so every warning is tried). A warning that already has an identical comment (same file, line and body) is skipped, so re-runs don't post duplicates. Rate-limited requests are retried a few times; if a comment still can't be posted (e.g. rate limiting or a network error), it is logged as a workflow warning and the remaining comments are still attempted; annotations are always uploaded first.

The workflow token needs `checks: write` and `pull-requests: write` permissions.

On `pull_request` events, `actions/checkout` checks out a temporary merge commit by default, while the check run and comments are attached to the PR's head commit. Check out the head commit (`ref: ${{ github.event.pull_request.head.sha }}`, as in the example workflow below) so that reported line numbers match the PR.

Duplicate comments are only detected within a run and against comments that already exist, so two runs for the same PR that overlap can both post the same comment. Use a `concurrency` group per PR (as in the example workflow below) so that runs for the same PR are queued rather than run in parallel.

## Config options

These are the (required or recommended) options you can set for the runner.

- GITHUB_TOKEN (required): the [github token](https://docs.github.com/en/actions/security-guides/automatic-token-authentication), naturally :)
- REPORT_PATH: Path to an existing Brakeman JSON report, e.g. "tmp/brakeman.json". If not set, the action runs Brakeman itself in PROJECT_PATH.
- PROJECT_PATH: The path of the project you want to scan (in case you have multiple apps in a repo), relative to the repository root, e.g. `my_rails_app`. Absolute paths are rejected. Defaults to the value of the [GITHUB_WORKSPACE](https://docs.github.com/en/actions/learn-github-actions/environment-variables) envvar. When set, warning file paths are prefixed with it so annotations and PR comments land on the right files; this also applies to a report supplied via REPORT_PATH. Absolute warning paths (from `brakeman --absolute-paths`) are made relative to the report's `scan_info.app_path` first.
- GITHUB_LATEST_SHA: the commit that the check run and PR review comments are attached to. Defaults to the pull request's head commit (`github.event.pull_request.head.sha`), or `GITHUB_SHA` outside pull requests. PR comments are only posted when the event has a pull request.
- CUSTOM_MESSAGE_CONTENT: Something custom you want to add to the PR comments, e.g. a runbook or an emoji or a friendly message. Note that if you want a line break in CUSTOM_MESSAGE_CONTENT it is recommended to use `<br />` tags.

### Usage

```yml
- name: Brakeman
  uses: cookpad/brakeman-linter-action@v2.2.0
  env:
    GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
```

### Custom report

```yml
- name: Install gems
  run: |
    gem install brakeman -v 8.1.1
- name: brakeman report
  run: |
    brakeman -f json > tmp/brakeman.json || exit 0
- name: Brakeman
  uses: cookpad/brakeman-linter-action@v2.2.0
  env:
    GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
    REPORT_PATH: tmp/brakeman.json
```

### Custom path

```yml
- name: Brakeman
  uses: cookpad/brakeman-linter-action@v2.2.0
  env:
    GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
    PROJECT_PATH: my_rails_app
```

### Example Workflow

```
name: Brakeman

on:
  pull_request:
  push:
    branches: [main]

permissions:
  contents: read
  checks: write
  pull-requests: write

concurrency:
  group: brakeman-${{ github.event.pull_request.number || github.ref }}
  cancel-in-progress: false

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
    - uses: actions/checkout@v6
      with:
        ref: ${{ github.event.pull_request.head.sha || github.sha }}
    - name: Brakeman
      uses: cookpad/brakeman-linter-action@v2.2.0
      env:
        GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        CUSTOM_MESSAGE_CONTENT: "This is a cool, friendly comment!<br />Thank you for improving our security!"
```

Remember: if you want a line break in CUSTOM_MESSAGE_CONTENT it is recommended to use `<br />` tags.

## Development

Git hooks are managed with [prek](https://github.com/j178/prek). After cloning, run:

```sh
prek install
```

The hooks run zizmor, actionlint and pinact when workflows (and, for zizmor, `dependabot.yml` and `.pre-commit-config.yaml`) change. Each tool is pinned in `.pre-commit-config.yaml` and installed by prek itself on first run (including a Go toolchain if needed), so nothing else needs to be installed beforehand.

Run the tests and linter with:

```sh
bundle exec rspec
bundle exec rubocop
```
