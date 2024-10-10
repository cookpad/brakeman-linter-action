# frozen_string_literal: true

require "net/http"
require "json"
require "time"
require_relative "report_adapter"
require_relative "github_check_run_service"
require_relative "github_client"

def read_json(path)
  JSON.parse(File.read(path))
end

project_path = if ENV["PROJECT_PATH"].nil?
                 ENV.fetch("GITHUB_WORKSPACE",
                   nil)
               else
                 "#{ENV.fetch('GITHUB_WORKSPACE', nil)}/#{ENV['PROJECT_PATH']}"
               end

@event_json = read_json(ENV["GITHUB_EVENT_PATH"]) if ENV["GITHUB_EVENT_PATH"]
@github_data = {
  sha: ENV.fetch("GITHUB_SHA", nil),
  latest_commit_sha: ENV.fetch("GITHUB_LATEST_SHA", nil),
  token: ENV.fetch("GITHUB_TOKEN", nil),
  owner: ENV["GITHUB_REPOSITORY_OWNER"] || @event_json.dig("repository", "owner", "login"),
  repo: ENV["GITHUB_REPOSITORY_NAME"] || @event_json.dig("repository", "name"),
  pull_request_number: ENV["GITHUB_PULL_REQUEST_NUMBER"] || @event_json.dig("pull_request", "number"),
  custom_message_content: ENV["CUSTOM_MESSAGE_CONTENT"] || ""
}

@report =
  if ENV["REPORT_PATH"]
    read_json(ENV["REPORT_PATH"])
  else
    Dir.chdir(project_path) { JSON.parse(`brakeman -f json`) }
  end

GithubCheckRunService.new(@report, @github_data, ReportAdapter).run
