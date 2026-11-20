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

  context "when rate limited" do
    let(:success) { { status: 200, body: "[]" } }

    before do
      allow(client).to receive(:sleep)
      allow($stdout).to receive(:puts)
    end

    it "retries a 429 after the Retry-After delay" do
      stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => "2" } }, success)
      client.get("/repos/owner/repo/pulls/10/comments")
      expect(client).to have_received(:sleep).with(2)
    end

    it "returns the response that follows the retry" do
      stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => "2" } }, success)
      expect(client.get("/repos/owner/repo/pulls/10/comments")).to eq([])
    end

    it "waits until the primary rate limit resets" do
      limit = { "X-RateLimit-Remaining" => "0", "X-RateLimit-Reset" => (Time.now.to_i + 30).to_s }
      stub_request(:get, url).to_return({ status: 403, headers: limit }, success)
      client.get("/repos/owner/repo/pulls/10/comments")
      expect(client).to have_received(:sleep).with(be_within(2).of(31))
    end

    it "backs off for a minute on a secondary rate limit without headers" do
      secondary = { status: 403, body: %({"message":"You have exceeded a secondary rate limit"}) }
      stub_request(:post, url).to_return(secondary, success)
      client.post("/repos/owner/repo/pulls/10/comments")
      expect(client).to have_received(:sleep).with(60)
    end

    it "logs each retry as a workflow warning" do
      allow($stdout).to receive(:puts).and_call_original
      stub_request(:get, url).to_return({ status: 429, headers: { "Retry-After" => "2" } }, success)
      expect { client.get("/repos/owner/repo/pulls/10/comments") }.
        to output(%r{::warning::GitHub rate limit hit, retrying in 2s \(retry 1/3\)}).to_stdout
    end

    it "gives up after three retries" do # rubocop:disable RSpec/MultipleExpectations -- raise_error guards the call
      stub_request(:get, url).to_return(status: 429, headers: { "Retry-After" => "1" })
      expect { client.get("/repos/owner/repo/pulls/10/comments") }.to raise_error(GithubClient::RequestError)
      expect(a_request(:get, url)).to have_been_made.times(4)
    end

    it "does not wait beyond the total wait budget" do # rubocop:disable RSpec/MultipleExpectations -- raise_error guards the call
      stub_request(:get, url).to_return(status: 429, headers: { "Retry-After" => "301" })
      expect { client.get("/repos/owner/repo/pulls/10/comments") }.to raise_error(GithubClient::RequestError)
      expect(client).not_to have_received(:sleep)
    end
  end

  it "does not retry a 403 that is not a rate limit" do # rubocop:disable RSpec/MultipleExpectations -- raise_error guards the call
    stub_request(:post, url).to_return(status: [403, "Forbidden"], body: %({"message":"Resource not accessible"}))
    expect { client.post("/repos/owner/repo/pulls/10/comments") }.to raise_error(GithubClient::RequestError)
    expect(a_request(:post, url)).to have_been_made.once
  end

  it "raises with the status message and body for other failures" do
    stub_request(:post, url).to_return(status: [403, "Forbidden"], body: '{"message":"nope"}')
    expect { client.post("/repos/owner/repo/pulls/10/comments") }.
      to raise_error(GithubClient::RequestError, 'Forbidden: {"message":"nope"}')
  end
end
