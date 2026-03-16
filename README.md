## Brakeman results parser github action

Brakeman is a static analysis tool which checks Ruby on Rails applications for security vulnerabilities.

You can read more about Brakeman itself [here](https://github.com/presidentbeef/brakeman).

This action helps make sure that brakeman results get accurately added to pull requests, in the event of a new issue.

Currently we recommend hardcoding the brakeman version (e.g. 8.0.4) to prevent the unintended consequences of pulling down the latest version
regardless of context.

## Config options

These are the (required or recommended) options you can set for the runner.

- GITHUB_TOKEN (required): the [github token](https://docs.github.com/en/actions/security-guides/automatic-token-authentication), naturally :)
- REPORT_PATH: Where on the action runner you want the report to go, e.g. "/tmp/report.json". If not set, just outputs a json string.
- PROJECT_PATH: The path of the project you want to scan (in case you have multiple apps in a repo). Defaults to the value of the [GITHUB_WORKSPACE](https://docs.github.com/en/actions/learn-github-actions/environment-variables) envvar.
- GITHUB_LATEST_SHA: recommend setting this, it tells the runner where to put review comments. Easiest set as  `${{ github.event.pull_request.head.sha }}`
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
    gem install brakeman -v 8.0.4
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

on: [push]

jobs:
  build:
    runs-on: ubuntu-24.04
    steps:
    - uses: actions/checkout@v1
    - name: Brakeman
      uses: cookpad/brakeman-linter-action@v2.2.0
      env:
        GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        GITHUB_LATEST_SHA: ${{ github.event.pull_request.head.sha }}
        CUSTOM_MESSAGE_CONTENT: "This is a cool, friendly comment!<br />Thank you for improving our security!"
```

Remember: if you want a line break in CUSTOM_MESSAGE_CONTENT it is recommended to use `<br />` tags.
