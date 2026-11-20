# frozen_string_literal: true

class GithubCheckRunService
  CHECK_NAME = "Brakeman"
  MAX_ANNOTATIONS_SIZE = 50
  PER_PAGE = 100
  PULL_REQUEST_FILES_LIMIT = 3000
  EMOJI_MAPPER = { High: "🚨", Medium: "⚠️", Weak: "❔" }.freeze
  BRAKEMAN_URL = "https://brakemanscanner.org/docs/warning_types/"
  def initialize(report, github_data, report_adapter)
    @report = report
    @github_data = github_data
    @report_adapter = report_adapter
    @client = GithubClient.new(@github_data[:token], user_agent: "brakeman-action")
  end

  def run
    id = @client.post(
      annotation_endpoint_url,
      create_check_payload
    )["id"]
    @summary = @report_adapter.summary(@report)
    @annotations = @report_adapter.annotations(@report)
    @conclusion = @report_adapter.conclusion(@report)
    upload_annotations(id)
    post_pull_request_comments
  end

  private

    def upload_annotations(id)
      return client_patch_annotations(id, []) if @annotations.empty?

      @annotations.each_slice(MAX_ANNOTATIONS_SIZE) { |batch| client_patch_annotations(id, batch) }
    end

    def post_pull_request_comments
      return if @annotations.empty? || !@github_data[:pull_request_number]

      changed_files = fetch_changed_files
      @existing_comments = fetch_existing_comments
    rescue GithubClient::RequestError => e
      puts "::warning::Could not fetch pull request data, skipping PR comments: #{e.message}"
    else
      file_list_complete = changed_files.size < PULL_REQUEST_FILES_LIMIT
      @annotations.each do |annotation|
        client_post_pull_requests(annotation) if !file_list_complete || changed_files.include?(annotation["path"])
      end
    end

    def fetch_changed_files
      fetch_all_pages(pull_request_files_url).map { |file| file["filename"] }
    end

    def fetch_existing_comments
      fetch_all_pages(pull_request_endpoint_url).map do |comment|
        { path: comment["path"], line: comment["line"], body: comment["body"] }
      end
    end

    def client_patch_annotations(id, annotations)
      @client.patch(
        "#{annotation_endpoint_url}/#{id}",
        update_check_payload(annotations)
      )
    end

    def client_post_pull_requests(annotation)
      payload = create_pull_request_comment_payload(annotation)
      key = payload.slice(:path, :line, :body)
      return if @existing_comments.include?(key)

      @client.post(pull_request_endpoint_url, payload)
      @existing_comments << key
    rescue GithubClient::IssueExistsOutsideOfPullRequestError
      puts "**************************************************************************"
      puts "* Brakeman has detected an issue elsewhere, outside of this Pull Request *"
      puts "* Please check the results above to see where & what needs to be fixed.  *"
      puts "**************************************************************************"
    rescue GithubClient::RequestError => e
      puts "::warning::Could not post PR comment on #{annotation['path']}:#{annotation['start_line']}: #{e.message}"
    end

    def fetch_all_pages(url)
      items = []
      page = 1
      loop do
        batch = @client.get("#{url}?per_page=#{PER_PAGE}&page=#{page}")
        items.concat(batch)
        break if batch.size < PER_PAGE

        page += 1
      end
      items
    end

    def annotation_endpoint_url
      "/repos/#{@github_data[:owner]}/#{@github_data[:repo]}/check-runs"
    end

    def pull_request_endpoint_url
      "/repos/#{@github_data[:owner]}/#{@github_data[:repo]}/pulls/#{@github_data[:pull_request_number]}/comments"
    end

    def pull_request_files_url
      "/repos/#{@github_data[:owner]}/#{@github_data[:repo]}/pulls/#{@github_data[:pull_request_number]}/files"
    end

    def create_check_payload
      {
        name: CHECK_NAME,
        head_sha: @github_data[:sha],
        status: "in_progress",
        started_at: Time.now.iso8601
      }
    end

    def update_check_payload(annotations)
      {
        name: CHECK_NAME,
        head_sha: @github_data[:sha],
        status: "completed",
        completed_at: Time.now.iso8601,
        conclusion: @conclusion,
        output: {
          title: CHECK_NAME,
          summary: @summary,
          annotations:
        }
      }
    end

    def create_pull_request_comment_payload(annotation)
      {
        commit_id: @github_data[:sha],
        path: annotation["path"],
        body: comment_body_generator(annotation),
        start_side: "RIGHT",
        line: annotation["start_line"]
      }
    end

    def get_confidence_level(title)
      title.split("-")[0].strip
    end

    def get_potential_vuln_type(title)
      title.split("-")[1].strip
    end

    def confidence_level_map(title)
      EMOJI_MAPPER[get_confidence_level(title).to_sym] || "⁉️"
    end

    def comment_body_generator(annotation)
      title = annotation["title"]
      emoji = confidence_level_map(title)
      "#{emoji} **Potential Vulnerability Detected** #{emoji}<br /><br />" +
        "**Confidence level**: #{get_confidence_level(title)}<br />" +
        "**Type**: #{get_potential_vuln_type(title)}<br />" +
        "**Description**: #{annotation['message']}<br />" +
        "**More information available at**: #{BRAKEMAN_URL}<br />" +
        @github_data[:custom_message_content].to_s
    end
end
