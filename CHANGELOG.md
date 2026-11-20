# Changelog

## Unreleased (pre-release)

- Fixes the check run staying "in progress" forever when Brakeman reports no warnings; it now completes as a success
- Fails the check when Brakeman reports scan errors (e.g. a file it could not parse) and lists them in the check summary, truncated to fit GitHub's 65,535-byte limit
- Tries every warning for PR comments when the PR has 3,000 or more changed files, since GitHub can't list them all
- Treats network failures (timeouts, connection resets, DNS and TLS errors) like failed requests, so they skip a PR comment instead of failing the action
- Retries GitHub API requests that hit a rate limit (429, or a 403 caused by a rate limit), honouring `Retry-After` and `x-ratelimit-reset`; at most 3 retries per request and 5 minutes of waiting per run
- Skips PR comments with a workflow warning, instead of failing, when the PR's changed files or existing comments can't be fetched; clean scans make no PR requests
- Fixes only the first warning in each batch of 50 getting a PR comment; every warning in a file changed by the PR now gets one
- Skips PR comments that already exist (same file, line and body), including duplicates within the same run, so re-runs no longer post duplicates
- Uploads all annotations before posting PR comments; a comment that fails (e.g. rate limiting) is logged as a workflow warning and the remaining comments are still attempted
- Fixes successful responses mentioning `diff_hunk` being treated as errors, and 422 errors on `pull_request_review_thread.line` aborting the run
- Fixes the action crashing on non-PR events (e.g. `push`), including when `GITHUB_PULL_REQUEST_NUMBER` is set to an empty value; PR comments are now only posted when the event has a pull request
- Fixes PR comments failing when `GITHUB_LATEST_SHA` is not set; it now defaults to the pull request's head commit
- Fixes annotations and PR comments pointing at the wrong files when `PROJECT_PATH` is set
- Fixes absolute warning paths (from `brakeman --absolute-paths`) by making them relative to the report's `scan_info.app_path`
- Attaches the check run to the pull request's head commit instead of the temporary merge commit, so it shows up on the PR

Behaviour changes:

- `GITHUB_LATEST_SHA` now also sets the commit the check run is attached to, not just the PR comments. Resolution order: `GITHUB_LATEST_SHA`, then the PR head commit, then `GITHUB_SHA`. An empty value is treated as unset.
- When `PROJECT_PATH` is set, warning paths are prefixed with it, including for reports supplied via `REPORT_PATH`.
- An absolute `PROJECT_PATH` now stops the action with an error; it must be relative to the repository root.
- A report with scan errors but no warnings now fails the check instead of passing.

Before releasing:

- Update the `uses: cookpad/brakeman-linter-action@v2.2.0` examples in the README to this release; the example workflow relies on these fixes.

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
