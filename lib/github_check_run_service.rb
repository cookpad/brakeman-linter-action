# frozen_string_literal: true

class GithubCheckRunService
  CHECK_NAME = 'Brakeman'
  MAX_ANNOTATIONS_SIZE = 50

  def initialize(report, github_data, report_adapter)
    @report = report
    @github_data = github_data
    @report_adapter = report_adapter
    @client = GithubClient.new(@github_data[:token], user_agent: 'brakeman-action')
  end

  def run
    id = @client.post(
      annotation_endpoint_url,
      create_check_payload
    )['id']
    @summary = @report_adapter.summary(@report)
    @annotations = @report_adapter.annotations(@report)
    @conclusion = @report_adapter.conslusion(@report)

    result = {}
    @annotations.each_slice(MAX_ANNOTATIONS_SIZE) do |annotation|
      result.merge(client_patch_annotations(id, annotation))
      result.merge(client_post_pull_requests(annotation))
    end
    result
  end

  private

  def client_patch_annotations(id, annotations)
    @client.patch(
      "#{annotation_endpoint_url}/#{id}",
      update_check_payload(annotations)
    )
  end

  def client_post_pull_requests(annotations)
    @client.post(
      "#{pull_request_endpoint_url}",
      create_pull_request_comment_payload(annotations)
    )
  end

  def annotation_endpoint_url
    "/repos/#{@github_data[:owner]}/#{@github_data[:repo]}/check-runs"
  end

  def pull_request_endpoint_url
    "/repos/#{@github_data[:owner]}/#{@github_data[:repo]}/pulls/#{@github_data[:pull_request_number]}/comments"
  end

  def create_check_payload
    {
      name: CHECK_NAME,
      head_sha: @github_data[:sha],
      status: 'in_progress',
      started_at: Time.now.iso8601
    }
  end

  def update_check_payload(annotations)
    {
      name: CHECK_NAME,
      head_sha: @github_data[:sha],
      status: 'completed',
      completed_at: Time.now.iso8601,
      conclusion: @conclusion,
      output: {
        title: CHECK_NAME,
        summary: @summary,
        annotations: annotations
      }
    }
  end

  def create_pull_request_comment_payload(annotations)
    {
      name: CHECK_NAME,
      head_sha: @github_data[:sha],
      status: 'completed',
      completed_at: Time.now.iso8601,
      conclusion: @conclusion,
      output: {
        title: CHECK_NAME,
        summary: @summary,
        annotations: annotations
      }
    }
  end
end
