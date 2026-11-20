# frozen_string_literal: true

require "./spec/spec_helper"
require "open3"
require "tmpdir"

describe "lib/index.rb" do # rubocop:disable RSpec/DescribeClass -- index.rb is a script, not a class
  let(:comments_url) { "https://api.github.com/repos/owner/repository_name/pulls/10/comments" }
  let(:tmpdir) { Dir.mktmpdir }
  let(:check_run_updates) { [] }
  let(:event_path) { File.join(tmpdir, "event.json").tap { |path| File.write(path, event.to_json) } }
  let(:event) do
    {
      "repository" => { "owner" => { "login" => "owner" }, "name" => "repository_name" },
      "pull_request" => { "number" => 10, "head" => { "sha" => "head-sha" } }
    }
  end

  after { FileUtils.remove_entry(tmpdir) }

  def changed_files
    files = JSON.parse(File.read("./spec/fixtures/report.json"))["warnings"].map { |warning| warning["file"] }.uniq
    files + files.map { |file| "my_rails_app/#{file}" }
  end

  before do
    stub_request(:post, "https://api.github.com/repos/owner/repository_name/check-runs").
      to_return(status: 200, body: '{"id": "id"}')
    stub_request(:patch, "https://api.github.com/repos/owner/repository_name/check-runs/id").
      to_return do |request|
        check_run_updates << request.body
        { status: 200, body: "{}" }
      end
    stub_request(:get, comments_url).with(query: hash_including({})).to_return(status: 200, body: "[]")
    stub_request(:get, "https://api.github.com/repos/owner/repository_name/pulls/10/files").
      with(query: hash_including({})).
      to_return(status: 200, body: changed_files.map { |filename| { "filename" => filename } }.to_json)
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

  context "when the action runs Brakeman itself" do
    def brakeman_env
      { "REPORT_PATH" => nil, "GITHUB_WORKSPACE" => tmpdir }
    end

    def brakeman_result(stdout, stderr, exitstatus)
      [stdout, stderr, instance_double(Process::Status, exitstatus:)]
    end

    it "runs Brakeman in the workspace and reports its JSON output" do
      allow(Open3).to receive(:capture3).
        and_return(brakeman_result(File.read("./spec/fixtures/report.json"), "", 3))
      run_action(brakeman_env)
      expect(Open3).to have_received(:capture3).with("brakeman", "-f", "json", chdir: tmpdir)
    end

    it "stops with Brakeman's exit status and output when it doesn't produce JSON" do
      allow(Open3).to receive(:capture3).and_return(brakeman_result("", "Please supply the path to a Rails application.", 4))
      expect { run_action(brakeman_env) }.
        to raise_error(SystemExit).
        and output(/::error::Brakeman did not produce a JSON report \(exit status 4\).*Please supply the path/m).
        to_stderr
    end

    it "doesn't let Brakeman's output start its own workflow command" do
      allow(Open3).to receive(:capture3).and_return(brakeman_result("", "parse error near:\n::add-mask::hidden", 1))
      expect { run_action(brakeman_env) }.
        to raise_error(SystemExit).
        and output(satisfy { |err| err.lines.none? { |line| line.start_with?("::add-mask::") } }).to_stderr
    end
  end

  it "reports to the repository from the event even if GITHUB_REPOSITORY_NAME is set" do
    stub_request(:any, %r{/repos/owner/other_repo/})
    run_action("GITHUB_REPOSITORY_NAME" => "other_repo")
    expect(a_request(:post, "https://api.github.com/repos/owner/repository_name/check-runs")).to have_been_made.once
  end

  it "creates the check run on the PR head commit, not the merge commit" do
    run_action({})
    expect(
      a_request(:post, "https://api.github.com/repos/owner/repository_name/check-runs").
        with(body: hash_including("head_sha" => "head-sha"))
    ).to have_been_made.once
  end

  context "when the event is a push" do
    let(:event) { { "repository" => { "owner" => { "login" => "owner" }, "name" => "repository_name" } } }

    it "creates the check run on GITHUB_SHA when GITHUB_LATEST_SHA is empty" do
      run_action("GITHUB_LATEST_SHA" => "")
      expect(
        a_request(:post, "https://api.github.com/repos/owner/repository_name/check-runs").
          with(body: hash_including("head_sha" => "merge-sha"))
      ).to have_been_made.once
    end

    it "does not touch PR comments when GITHUB_PULL_REQUEST_NUMBER is empty" do
      run_action("GITHUB_PULL_REQUEST_NUMBER" => "")
      expect(a_request(:any, %r{/pulls/})).not_to have_been_made
    end

    it "comments on the PR given by GITHUB_PULL_REQUEST_NUMBER and GITHUB_LATEST_SHA" do
      run_action("GITHUB_PULL_REQUEST_NUMBER" => "10", "GITHUB_LATEST_SHA" => "pr-head-sha")
      expect(a_request(:post, comments_url).with(body: hash_including("commit_id" => "pr-head-sha"))).
        to have_been_made.times(25)
    end
  end

  def annotated_paths
    check_run_updates.flat_map { |body| JSON.parse(body)["output"]["annotations"].map { |a| a["path"] } }
  end

  def absolute_paths_report_path
    report = JSON.parse(File.read("./spec/fixtures/report.json"))
    report["warnings"].each { |warning| warning["file"] = File.join(report["scan_info"]["app_path"], warning["file"]) }
    File.join(tmpdir, "absolute_report.json").tap { |path| File.write(path, report.to_json) }
  end

  context "when the report has absolute warning paths" do
    it "makes them relative to the scanned app" do
      run_action("REPORT_PATH" => absolute_paths_report_path)
      expect(annotated_paths).to include("app/controllers/password_resets_controller.rb").
        and(all(satisfy { |path| !path.start_with?("/") }))
    end

    it "prefixes them with PROJECT_PATH" do
      run_action("REPORT_PATH" => absolute_paths_report_path, "PROJECT_PATH" => "my_rails_app")
      expect(annotated_paths).to include("my_rails_app/app/controllers/password_resets_controller.rb").
        and(all(start_with("my_rails_app/")))
    end
  end

  context "when PROJECT_PATH is absolute" do
    it "stops with an error before contacting GitHub" do
      expect { run_action("PROJECT_PATH" => "/github/workspace/my_rails_app") }.
        to raise_error(SystemExit).
        and output(%r{::error::PROJECT_PATH must be relative to the repository root, got "/github/workspace/my_rails_app"}).
        to_stderr
    end

    it "makes no GitHub requests" do # rubocop:disable RSpec/MultipleExpectations -- raise_error only guards the abort
      allow($stderr).to receive(:write)
      expect { run_action("PROJECT_PATH" => "/github/workspace/my_rails_app") }.to raise_error(SystemExit)
      expect(a_request(:any, /api.github.com/)).not_to have_been_made
    end
  end

  it "annotates paths relative to the repo root when PROJECT_PATH is not set" do
    run_action({})
    expect(annotated_paths).to include("app/controllers/password_resets_controller.rb")
  end

  ["my_rails_app", "./my_rails_app/"].each do |project_path|
    context "when PROJECT_PATH is #{project_path.inspect}" do
      it "prefixes annotation paths with the project directory" do
        run_action("PROJECT_PATH" => project_path)
        expect(annotated_paths).to all(start_with("my_rails_app/")).
          and include("my_rails_app/app/controllers/password_resets_controller.rb")
      end

      it "prefixes PR comment paths with the project directory" do
        run_action("PROJECT_PATH" => project_path)
        expect(
          a_request(:post, comments_url).
            with(body: hash_including("path" => "my_rails_app/app/controllers/password_resets_controller.rb"))
        ).to have_been_made.times(3)
      end
    end
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
