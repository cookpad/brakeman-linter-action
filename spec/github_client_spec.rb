# frozen_string_literal: true

require "./spec/spec_helper"

describe GithubClient do
  let(:client) { described_class.new("token") }
  let(:url) { "https://api.github.com/repos/owner/repo/pulls/10/comments" }

  def validation_failure(field)
    {
      message: "Validation Failed",
      errors: [{ resource: "PullRequestReviewComment", code: "invalid", field: }]
    }.to_json
  end

  it "parses a successful response even if it mentions an outside-diff field" do
    comments = [{ "body" => "pull_request_review_thread.diff_hunk came up in review" }]
    stub_request(:get, url).to_return(status: 200, body: comments.to_json)
    expect(client.get("/repos/owner/repo/pulls/10/comments")).to eq(comments)
  end

  ["pull_request_review_thread.diff_hunk", "pull_request_review_thread.line"].each do |field|
    it "raises IssueExistsOutsideOfPullRequestError for a 422 on #{field}" do
      stub_request(:post, url).to_return(status: 422, body: validation_failure(field))
      expect { client.post("/repos/owner/repo/pulls/10/comments") }.
        to raise_error(GithubClient::IssueExistsOutsideOfPullRequestError)
    end
  end

  it "raises with the status message and body for other failures" do
    stub_request(:post, url).to_return(status: [403, "Forbidden"], body: '{"message":"nope"}')
    expect { client.post("/repos/owner/repo/pulls/10/comments") }.
      to raise_error(RuntimeError, 'Forbidden: {"message":"nope"}')
  end
end
