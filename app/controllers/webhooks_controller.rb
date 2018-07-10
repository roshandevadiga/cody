class WebhooksController < ApplicationController
  include WebhookSecurity

  protect_from_forgery with: :null_session

  before_action :verify_webhook_signature!, only: %i[integration]

  def pull_request
    body = JSON.parse(request.body.read)

    if %w(opened synchronize closed).include?(body["action"])
      ReceivePullRequestEvent.perform_async(body)
    end

    head :accepted
  end

  def issue_comment
    body = JSON.parse(request.body.read)

    if body.key?("zen")
      head :ok
      return
    end

    ReceiveIssueCommentEvent.perform_async(body)
    head :accepted
  end

  # The entry point for webhooks from the GitHub app
  def integration
    body = JSON.parse(request.body.read)

    if body.key?("zen")
      head :ok
      return
    end

    request.body.rewind

    event = request.headers["X-GitHub-Event"]
    case event
    when "push"
      ReceivePushEvent.perform_async(
        body["repository"]["full_name"],
        body.dig("installation", "id")
      )
    when "pull_request"
      pull_request
      return
    when "issue_comment"
      issue_comment
      return
    when "installation"
      ReceiveInstallationRepositoriesEvent.perform_async(body["repositories"])
    when "installation_repositories"
      ReceiveInstallationRepositoriesEvent
        .perform_async(body["repositories_added"])
    end

    head :accepted
  end
end
