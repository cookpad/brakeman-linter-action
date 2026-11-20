# Changelog

## Unreleased (pre-release)

- Fixes the check run staying "in progress" forever when Brakeman reports no warnings; it now completes as a success
- Fixes only the first warning in each batch of 50 getting a PR comment; every warning now gets one
- Skips PR comments that already exist (same file, line and body), so re-runs no longer post duplicates
- Fixes the action crashing on non-PR events (e.g. `push`); PR comments are now only posted on `pull_request` events
- Fixes PR comments failing when `GITHUB_LATEST_SHA` is not set; it now defaults to the pull request's head commit
- Fixes annotations and PR comments pointing at the wrong files when `PROJECT_PATH` is set
- Attaches the check run to the pull request's head commit instead of the temporary merge commit, so it shows up on the PR

Behaviour changes:

- `GITHUB_LATEST_SHA` now also sets the commit the check run is attached to, not just the PR comments. Resolution order: `GITHUB_LATEST_SHA`, then the PR head commit, then `GITHUB_SHA`. An empty value is treated as unset.
- When `PROJECT_PATH` is set, warning paths are prefixed with it, including for reports supplied via `REPORT_PATH`.

## v2.3.0

- Adds support for Ruby 4.0.1 and Ruby 3.3 (test matrix now covers both)
- Updates to latest Brakeman
- Consolidates CI workflows into a single `ci.yml` with enforced job ordering (rubocop + dependency-review → tests → brakeman dogfooding)
- Fixes RuboCop failing in CI due to vendored gems being scanned (`vendor/` is now excluded)
- Adds support for Node 24 in GitHub Actions
- Adds support for `synchronize` event in GitHub Actions

## v2.2.0

- Update Dockerfile ruby and brakeman versions

## v2.1.0

- Shows a relevant error when an issue is detected outside the current PR
- Does not run forever when there aren't any annotations (thanks @dlackty!)

## v2.0.0

- Adds direct comments to PRs and changes API interactions. Note that this may break implementations of the action that rely on previous functionality/API interactions.

## v1.0.4

- Mostly spec improvements but also fixes an old API request

## v1.0.3

- Use token authentication correctly

## v1.0.2

- More useful verbose output

## v1.0.1

- Modify and update for Cookpad

## v1.0.0

- Create check run in github
- Adapter for brakeman report
