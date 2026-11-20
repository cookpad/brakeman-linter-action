# frozen_string_literal: true

require "./spec/spec_helper"

describe GithubCheckRunService do
  let(:no_findings_brakeman_report) { JSON(File.read("./spec/fixtures/no_findings_report.json")) }
  let(:brakeman_report) { JSON(File.read("./spec/fixtures/report.json")) }
  let(:github_data) { { sha: "sha", token: "token", owner: "owner", repo: "repository_name", pull_request_number: "10" } }
  let(:service) { described_class.new(brakeman_report, github_data, ReportAdapter) }

  def comments_url
    "https://api.github.com/repos/owner/repository_name/pulls/10/comments"
  end

  def stub_existing_comments(page, comments)
    stub_request(:get, comments_url).
      with(query: { "per_page" => "100", "page" => page.to_s }).
      to_return(status: 200, body: comments.to_json)
  end

  def stub_changed_files(page, filenames)
    stub_request(:get, "https://api.github.com/repos/owner/repository_name/pulls/10/files").
      with(query: { "per_page" => "100", "page" => page.to_s }).
      to_return(status: 200, body: filenames.map { |filename| { "filename" => filename } }.to_json)
  end

  def stub_check_run
    stub_request(:post, "https://api.github.com/repos/owner/repository_name/check-runs").
      to_return(status: 200, body: '{"id": "id"}')
    stub_request(:patch, "https://api.github.com/repos/owner/repository_name/check-runs/id").
      to_return(status: 200, body: "{}")
  end

  before do
    stub_existing_comments(1, [])
    stub_changed_files(1, brakeman_report["warnings"].map { |warning| warning["file"] }.uniq)
  end

  it "completes the check run as a failure when there are warnings" do
    stub_check_run
    stub_request(:post, comments_url).to_return(status: 200, body: '{"id": "id"}')
    service.run
    expect(a_request(:patch, "https://api.github.com/repos/owner/repository_name/check-runs/id").
      with(body: hash_including("status" => "completed", "conclusion" => "failure"))).to have_been_made.once
  end

  context "when only some warnings are in files changed by the PR" do
    before do
      stub_check_run
      stub_request(:post, comments_url).to_return(status: 200, body: '{"id": "id"}')
    end

    it "comments only on warnings in changed files" do
      stub_changed_files(1, ["app/controllers/password_resets_controller.rb"])
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(3)
    end

    it "finds changed files on a later page" do
      stub_changed_files(1, Array.new(100) { |i| "unrelated_#{i}.rb" })
      stub_changed_files(2, ["app/controllers/password_resets_controller.rb"])
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(3)
    end
  end

  context "when posting a PR comment fails" do
    before do
      stub_check_run
      stub_request(:post, comments_url).to_return(status: [403, "Forbidden"], body: '{"message":"rate limited"}')
      stub_const("GithubCheckRunService::MAX_ANNOTATIONS_SIZE", 2)
    end

    it "still uploads every annotation batch" do
      allow($stdout).to receive(:puts)
      service.run
      expect(a_request(:patch, "https://api.github.com/repos/owner/repository_name/check-runs/id")).
        to have_been_made.times(13)
    end

    it "logs a warning for the failed comment" do
      expect { service.run }.
        to output(%r{::warning::Could not post PR comment on app/controllers/password_resets_controller.rb:6}).
        to_stdout
    end

    it "attempts the remaining comments" do
      allow($stdout).to receive(:puts)
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(25)
    end
  end

  context "when the run is not for a pull request" do
    it "completes the check run without touching PR comments" do # rubocop:disable RSpec/ExampleLength
      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
        to_return(status: 200, body: "{}")

      described_class.new(brakeman_report, github_data.except(:pull_request_number), ReportAdapter).run

      expect(a_request(:any, %r{/pulls/})).not_to have_been_made
    end
  end

  context "when there are no findings" do
    it "completes the check run as a success" do # rubocop:disable RSpec/ExampleLength
      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
        to_return(status: 200, body: "{}")

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      described_class.new(no_findings_brakeman_report, github_data, ReportAdapter).run

      expect(
        a_request(:patch, "https://api.github.com/repos/owner/repository_name/check-runs/id").
          with(body: hash_including("status" => "completed", "conclusion" => "success"))
      ).to have_been_made.once
    end
  end

  context "when the annotation limit is set" do
    before do
      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
        to_return(status: 200, body: "{}")

      stub_request(:post, comments_url).to_return(status: 200, body: '{"id": "id"}')

      stub_const("GithubCheckRunService::MAX_ANNOTATIONS_SIZE", 2)
    end

    it "updates the check run once per batch of annotations" do
      service.run
      expect(a_request(:patch, "https://api.github.com/repos/owner/repository_name/check-runs/id")).
        to have_been_made.times(13)
    end

    it "posts a PR comment for every warning" do
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(25)
    end
  end

  context "when a warning already has an identical PR comment" do
    def existing_comment
      {
        "path" => "app/controllers/password_resets_controller.rb",
        "line" => 6,
        "body" => "⚠️ **Potential Vulnerability Detected** ⚠️<br /><br />" \
                  "**Confidence level**: Medium<br />" \
                  "**Type**: Deserialize<br />" \
                  "**Description**: `Marshal.load` called with parameter value<br />" \
                  "**More information available at**: https://brakemanscanner.org/docs/warning_types/<br />"
      }
    end

    before do
      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
        to_return(status: 200, body: "{}")

      stub_request(:post, comments_url).to_return(status: 200, body: '{"id": "id"}')
    end

    it "does not post that comment again" do
      stub_existing_comments(1, [existing_comment])
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(24)
    end

    it "finds the existing comment on a later page" do
      stub_existing_comments(1, Array.new(100, { "path" => "README.md", "line" => 1, "body" => "Nice" }))
      stub_existing_comments(2, [existing_comment])
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(24)
    end

    it "posts a warning only once when the report lists it twice" do
      brakeman_report["warnings"] << brakeman_report["warnings"].first.dup
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(25)
    end

    it "posts again when the existing comment is on a different line" do
      stub_existing_comments(1, [existing_comment.merge("line" => 7)])
      service.run
      expect(a_request(:post, comments_url)).to have_been_made.times(25)
    end
  end

  context "when posting PR comments" do
    it "comments on a pr" do # rubocop:disable RSpec/ExampleLength
      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/pulls/10/comments").
        to_return(status: 200, body: '{"id": "id"}')

      expected_comment_body = {
        "annotation_level" => "warning",
        "end_line" => 6,
        "message" => "`Marshal.load` called with parameter value",
        "path" => "app/controllers/password_resets_controller.rb",
        "start_line" => 6,
        "title" => "Medium - Deserialize"
      }

      allow(service).to receive(:client_post_pull_requests)
      service.run
      expect(service).to have_received(:client_post_pull_requests).with(expected_comment_body)
    end
  end

  # Eventually we'll have this comment, but for now, we don't want to fail with a mysterious github error
  context "when an issue is in the codebase but not in the PR" do
    it "does not fail the build" do # rubocop:disable RSpec/ExampleLength
      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/pulls/10/comments").
        to_return(status: 422, body: '{"message":"Validation Failed","errors":[{"resource":"PullRequestReviewComment","code":"invalid","field":"pull_request_review_thread.path"},{"resource":"PullRequestReviewComment","code":"missing_field","field":"pull_request_review_thread.diff_hunk"}],"documentation_url":"https://docs.github.com/rest"}')

      expect { service.run }.to output(/Brakeman has detected an issue elsewhere, outside of this Pull Request/).to_stdout
    end
  end
end
