# frozen_string_literal: true

require "net/http"
require "openssl"

class GithubClient
  class IssueExistsOutsideOfPullRequestError < StandardError
  end

  class RequestError < StandardError
  end

  OUTSIDE_DIFF_FIELDS = ["pull_request_review_thread.diff_hunk", "pull_request_review_thread.line"].freeze
  NETWORK_ERRORS = [
    Net::OpenTimeout, Net::ReadTimeout, Net::WriteTimeout, Errno::ECONNRESET, Errno::ECONNREFUSED,
    Errno::EHOSTUNREACH, Errno::ETIMEDOUT, SocketError, EOFError, OpenSSL::SSL::SSLError
  ].freeze
  MAX_RETRIES = 3
  MAX_TOTAL_WAIT_SECONDS = 300
  SECONDARY_RATE_LIMIT_WAIT_SECONDS = 60

  def initialize(github_token, user_agent: "ruby")
    @github_token = github_token
    @user_agent = user_agent
    @seconds_waited = 0
  end

  def get(url)
    request_http("GET", url) do |http|
      http.get(url, headers)
    end
  end

  def patch(url, body = {})
    request_http("PATCH", url) do |http|
      http.patch(url, body.to_json, headers)
    end
  end

  def post(url, body = {})
    request_http("POST", url) do |http|
      http.post(url, body.to_json, headers)
    end
  end

  private

    def headers
      @_headers ||= {
        "Content-Type": "application/json",
        Authorization: "token #{@github_token}",
        "User-Agent": @user_agent,
        Accept: "application/vnd.github.v3+json"
      }
    end

    def request_http(method, url, &)
      retries = 0
      loop do
        response = send_request(method, url, &)
        wait = retry_wait(response, retries)
        return parse_response(response) unless wait

        retries += 1
        puts "::warning::GitHub rate limit hit, retrying in #{wait}s (retry #{retries}/#{MAX_RETRIES})"
        @seconds_waited += wait
        sleep(wait)
      end
    end

    def send_request(method, url)
      http = Net::HTTP.new("api.github.com", 443)
      http.use_ssl = true
      yield(http)
    rescue *NETWORK_ERRORS => e
      raise RequestError, "#{method} #{url} failed: #{e.class}: #{e.message}"
    end

    def retry_wait(response, retries)
      return unless retries < MAX_RETRIES && rate_limited?(response)

      wait = rate_limit_wait(response, retries)
      wait if @seconds_waited + wait <= MAX_TOTAL_WAIT_SECONDS
    end

    def rate_limited?(response)
      return true if response.code == "429"

      return false unless response.code == "403"

      response["retry-after"] || response["x-ratelimit-remaining"] == "0" || response.body.to_s.match?(/rate limit/i)
    end

    def rate_limit_wait(response, retries)
      return response["retry-after"].to_i if response["retry-after"]
      return [response["x-ratelimit-reset"].to_i - Time.now.to_i, 0].max + 1 if response["x-ratelimit-remaining"] == "0"

      SECONDARY_RATE_LIMIT_WAIT_SECONDS * (2**retries)
    end

    def parse_response(response)
      raise IssueExistsOutsideOfPullRequestError if outside_diff_error?(response)
      raise RequestError, "#{response.message}: #{response.body}" if response.code.to_i >= 300

      JSON.parse(response.body)
    end

    def outside_diff_error?(response)
      response.code == "422" && OUTSIDE_DIFF_FIELDS.any? { |field| response.body.include?(field) }
    end
end
