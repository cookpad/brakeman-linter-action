# frozen_string_literal: true

require "./spec/spec_helper"
require "tmpdir"

describe "lib/index.rb" do # rubocop:disable RSpec/DescribeClass -- index.rb is a script, not a class
  let(:comments_url) { "https://api.github.com/repos/owner/repository_name/pulls/10/comments" }
  let(:tmpdir) { Dir.mktmpdir }
  let(:event_path) { File.join(tmpdir, "event.json").tap { |path| File.write(path, event.to_json) } }
  let(:event) do
    {
      "repository" => { "owner" => { "login" => "owner" }, "name" => "repository_name" },
      "pull_request" => { "number" => 10, "head" => { "sha" => "head-sha" } }
    }
  end

  after { FileUtils.remove_entry(tmpdir) }

  before do
    stub_request(:post, "https://api.github.com/repos/owner/repository_name/check-runs").
      to_return(status: 200, body: '{"id": "id"}')
    stub_request(:patch, "https://api.github.com/repos/owner/repository_name/check-runs/id").
      to_return(status: 200, body: "{}")
    stub_request(:get, comments_url).with(query: hash_including({})).to_return(status: 200, body: "[]")
    stub_request(:post, comments_url).to_return(status: 200, body: '{"id": "id"}')
  end

  def run_action(env)
    stub_const("ENV", {
      "GITHUB_EVENT_PATH" => event_path,
      "GITHUB_SHA" => "merge-sha",
      "GITHUB_TOKEN" => "token",
      "REPORT_PATH" => "./spec/fixtures/report.json"
    }.merge(env))
    load "./lib/index.rb"
  end

  it "comments on the PR head commit when GITHUB_LATEST_SHA is not set" do
    run_action({})
    expect(a_request(:post, comments_url).with(body: hash_including("commit_id" => "head-sha"))).
      to have_been_made.times(25)
  end

  it "comments on GITHUB_LATEST_SHA when it is set" do
    run_action("GITHUB_LATEST_SHA" => "latest-sha")
    expect(a_request(:post, comments_url).with(body: hash_including("commit_id" => "latest-sha"))).
      to have_been_made.times(25)
  end
end
