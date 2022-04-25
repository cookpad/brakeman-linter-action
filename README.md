## Brakeman results parser github action

Brakeman is a static analysis tool which checks Ruby on Rails applications for security vulnerabilities.

You can read more about Brakeman itself [here](https://github.com/presidentbeef/brakeman).

This action helps make sure that brakeman results get accurately added to pull requests, in the event of a new issue.

Currently we hardcode the brakeman version (5.2.1) to prevent the unintended consequences of pulling down the latest version
regardless of context.

### Usage

```yml
- name: Brakeman
  uses: cookpad/brakeman-linter-action@v1.0.4
  env:
    GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
```

### Custom report

```yml
- name: Install gems
  run: |
    gem install brakeman -v 5.2.1
- name: brakeman report
  run: |
    brakeman -f json > tmp/brakeman.json || exit 0
- name: Brakeman
  uses: cookpad/brakeman-linter-action@v1.0.4
  env:
    GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
    REPORT_PATH: tmp/brakeman.json
```

### Custom path

```yml
- name: Brakeman
  uses: cookpad/brakeman-linter-action@v1.0.4
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
    runs-on: ubuntu-20.04
    steps:
    - uses: actions/checkout@v1
    - name: Brakeman
      uses: cookpad/brakeman-linter-action@v1.0.4
      env:
        GITHUB_TOKEN: ${{secrets.GITHUB_TOKEN}}
        GITHUB_LATEST_SHA: ${{ github.event.pull_request.head.sha }}
        CUSTOM_MESSAGE_CONTENT: "This is a cool, friendly comment!<br />Thank you for improving our security!"
```

Note that if you want a line break in CUSTOM_MESSAGE_CONTENT it is recommended to use `<br />` tags.

## Screenshots

![example GitHub Action UI](./screenshots/action.png)
![example Pull request](./screenshots/pull_request.png)
