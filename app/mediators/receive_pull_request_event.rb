# frozen_string_literal: true

class ReceivePullRequestEvent
  include Sidekiq::Worker
  include Skylight::Helpers
  include GithubApi

  instrument_method
  def perform(payload)
    Current.reset

    @payload = payload

    Raven.user_context(
      username: @payload["sender"]["login"]
    )
    Raven.tags_context(
      event: "pull_request",
      repo: @payload["repository"]["full_name"]
    )

    if (installation_id = @payload.dig("installation", "id"))
      Current.installation_id = installation_id
    end

    # check for ignored labels
    @repository =
      Repository.find_by_full_name(@payload["repository"]["full_name"])

    labels = @payload["pull_request"]["labels"].map { |label| label["name"] }
    if @repository.ignore?(labels)
      github_client.create_status(
        @payload["repository"]["full_name"],
        @payload["pull_request"]["head"]["sha"],
        "pending",
        {
          context: "code-review/cody",
          description: PullRequest::STATUS_SKIPPED
        }
      )

      Current.reset
      return
    end

    PaperTrail.request(whodunnit: @payload["sender"]["login"]) do
      case @payload["action"]
      when "opened"
        self.on_opened
      when "synchronize"
        self.on_synchronize
      when "closed"
        self.on_closed
      when "unlabeled"
        self.on_unlabeled
      end
    end

    Current.reset
  end

  instrument_method
  def on_opened
    CreateOrUpdatePullRequest.new.perform(@payload["pull_request"])
  end

  instrument_method
  def on_closed
    number = @payload["number"]
    if (pr = @repository.pull_requests.find_by(number: number))
      if pr.status == "pending_review"
        pr.status = PullRequest::STATUS_CLOSED
        pr.save!
        pr.update_status("Pull Request closed")
      end
    end
  end

  # The "synchronize" event occurs whenever a new commit is pushed to the branch
  # or the branch is rebased.
  #
  # In this case, we preserve the current review status and update the new
  # commit with the correct status indicator.
  instrument_method
  def on_synchronize
    number = @payload["number"]
    if (pr = @repository.pull_requests.find_by(number: number))
      pr.update_status
    else
      CreateOrUpdatePullRequest.new.perform(@payload["pull_request"])
    end
  end

  # This function is called whenever a label is removed.
  #
  # If the repository no longer ignores the PR, and the PR is not recorded yet,
  # then we record the PR into the DB. Otherwise, if the PR already exists in
  # the DB, then this function does nothing. Only acting on never before seen
  # PRs should help reduce the amount of activity from this function.
  #
  # If the PR previously existed, that should mean that the PR was created
  # without any ignore labels on it, and an ignore label was added later. That
  # should mean that the PR already has reviewers assigned, and we don't want
  # the unlabel action to change reviewers.
  def on_unlabeled
    labels = @payload["pull_request"]["labels"].map { |label| label["name"] }
    number = @payload["number"]
    if !@repository.ignore?(labels) &&
        !@repository.pull_requests.exists?(number: number)

      CreateOrUpdatePullRequest.new.perform(@payload["pull_request"])
    end
  end
end
