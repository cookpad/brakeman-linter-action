# frozen_string_literal: true

require "webmock/rspec"
require "json"
require "pry"
require "./lib/report_adapter"
require "./lib/github_check_run_service"
require "./lib/github_client"
require "./lib/workflow_command"

RSpec.configure do |config|
  config.before do
    # rubocop:disable-next RSpec/AnyInstance -- clients are built inside the service; a retry must never sleep for real
    allow_any_instance_of(GithubClient).to receive(:sleep)
  end
end
