# frozen_string_literal: true

require "./spec/spec_helper"

describe GithubCheckRunService do
  let(:brakeman_report) { JSON(File.read("./spec/fixtures/report.json")) }
  let(:github_data) { { sha: "sha", token: "token", owner: "owner", repo: "repository_name", pull_request_number: "10" } }
  let(:service) { GithubCheckRunService.new(brakeman_report, github_data, ReportAdapter) }

  it "#run" do
    stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
      to_return(status: 200, body: "{}")

    stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
      to_return(status: 200, body: '{"id": "id"}')

    stub_request(:any, "https://api.github.com/repos/owner/repository_name/pulls/10/comments").
      to_return(status: 200, body: '{"id": "id"}')

    output = service.run
    expect(output).to be_a(Hash)
  end

  context "annotation limit set" do
    it "updates the check run multiple times" do
      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/pulls/10/comments").
        to_return(status: 200, body: '{"id": "id"}')

      stub_const("GithubCheckRunService::MAX_ANNOTATIONS_SIZE", 2)
      allow(service).to receive(:client_patch_annotations).and_return({})
      expect(service).to receive(:client_patch_annotations).exactly(13).times
      allow(service).to receive(:client_post_pull_requests).and_return({})
      expect(service).to receive(:client_post_pull_requests).exactly(13).times
      service.run
    end
  end

  context "pr comments" do
    it "comments on a pr" do
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
      expect(service).to receive(:client_post_pull_requests).with(expected_comment_body)
      service.run
    end
  end

  # Eventually we'll have this comment, but for now, we don't want to fail the build
  context "an issue in the codebase but not in the PR" do
    it "does not fail the build" do
      expected_pr_comment_body = {
        body: "⚠️ **Potential Vulnerability Detected Outside Of PR** ⚠️<br /><br />You might not need to deal with this, but be aware that it exists in the codebase.<br />**Confidence level**: Medium<br />**Type**: Deserialize<br />**Description**: `Marshal.load` called with parameter value<br />**More information available at**: https://brakemanscanner.org/docs/warning_types/<br />**Location**: app/controllers/password_resets_controller.rb:6<br />"
      }
      expected_file_comment_body = {
        "annotation_level" => "warning",
        "end_line" => 6,
        "message" => "`Marshal.load` called with parameter value",
        "path" => "app/controllers/password_resets_controller.rb",
        "start_line" => 6,
        "title" => "Medium - Deserialize"
      }

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/check-runs/id").
        to_return(status: 200, body: '{"id": "id"}')

      stub_request(:any, "https://api.github.com/repos/owner/repository_name/pulls/10/comments").
        to_return(status: 422, body: '{"message":"Validation Failed","errors":[{"resource":"PullRequestReviewComment","code":"invalid","field":"pull_request_review_thread.path"},{"resource":"PullRequestReviewComment","code":"missing_field","field":"pull_request_review_thread.diff_hunk"}],"documentation_url":"https://docs.github.com/rest"}').
        times(1)

      stub_request(:post, "https://api.github.com/repos/owner/repository_name/pulls/10/comments").
        with(expected_pr_comment_body).
        to_return(status: 200, body: '{"id": "id"}').
        times(1)

      expect(service).to receive(:client_post_pull_request_for_issue_outside_of_pr).with(expected_file_comment_body).once.
        and_return(expected_pr_comment_body)
      expect { service.run }.not_to raise_error
    end
  end
end
