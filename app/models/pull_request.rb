# frozen_string_literal: true

class PullRequest < ApplicationRecord
  validates :number, numericality: true, presence: true
  validates :status, presence: true

  serialize :pending_reviews, JSON
  serialize :completed_reviews, JSON

  after_save :update_child_pull_requests, if: -> { saved_change_to_status? }

  scope :pending_review, -> { where(status: "pending_review") }

  belongs_to :repository, required: true
  belongs_to :parent_pull_request, required: false, class_name: "PullRequest"
  has_many :reviewers

  has_paper_trail

  delegate :installation, to: :repository

  REVIEW_LINK_REGEX = /\s*^(?:R|r)eview(?:ed)?\s+in\s+#(\d+)\s*$/
  REVIEWER_CHECKBOX_REGEX = /[*-] +\[([ x])\] +@([A-Za-z0-9_-]+)/

  STATUS_APRICOT = "APRICOT: Too few reviewers are listed".freeze
  STATUS_AVOCADO = "AVOCADO: PR does not meet super-review threshold".freeze
  STATUS_PLUM = "PLUM: %{reviewers} %{verb_phrase} on this repository".freeze
  STATUS_DELEGATED = "Review is delegated to #%{parent_number}".freeze
  STATUS_SKIPPED = "Code reviewers were not assigned".freeze

  STATUS_PENDING_REVIEW = "pending_review".freeze
  STATUS_APPROVED = "approved".freeze
  STATUS_CLOSED = "closed".freeze

  COMMIT_STATUS_DESCRIPTIONS = {
    "pending" => "Not all reviewers have approved",
    "success" => "Code review complete",
    "failure" => "%s"
  }.freeze

  include GithubApi

  def owner
    self.repository.owner
  end

  def repo
    self.repository.name
  end

  # List authors of commits in this pull request
  #
  # Returns the Array listing of all commit authors
  def commit_authors
    return [] unless repository

    commits = github_client.pull_request_commits(
      self.repository.full_name,
      number
    )

    commits.map { |commit|
      if author = commit[:author]
        author[:login]
      end
    }.compact
  end

  def assign_reviewers
    github_client.update_issue(
      self.repository.full_name,
      self.number,
      assignees: self.pending_review_logins
    )
  end

  def update_status(message = nil)
    github_client.create_status(
      self.repository.full_name,
      self.head_sha,
      commit_status,
      commit_status_details(message)
    )
  end

  def resource
    @resource ||= github_client.pull_request(
      self.repository.full_name,
      self.number
    )
  end

  def head_sha
    self.resource.head.sha
  end

  def html_url
    self.resource.html_url
  end

  def full_title
    "#{self.repository.full_name}##{self.number}: #{self.resource.title}"
  end

  def link_by_number(number)
    parent_pr = PullRequest.find_by(
      number: number,
      repository_id: self.repository_id
    )
    return unless parent_pr

    self.parent_pull_request = parent_pr
    self.status = self.parent_pull_request.status
    self.save!
  end

  def generated_reviewers
    reviewers.from_rule
  end

  def pending_review_logins
    reviewers.pending_review.map(&:login)
  end

  def target_url
    Rails.application.routes.url_helpers.pull_url(
      repo: self.repo,
      owner: self.owner,
      number: self.number,
      host: ENV["CODY_HOST"],
      protocol: "https"
    )
  end

  def update_body
    addendum = +<<~ADDENDUM
      ## Generated Reviewers

    ADDENDUM

    generated_reviewers.each do |reviewer|
      addendum << reviewer.addendum
    end

    # Drop existing Generated Reviewers section and replace with new one
    old_body = self.resource["body"]
    prelude, _ = old_body.split(ReviewRule::GENERATED_REVIEWERS_REGEX, 2)
    prelude ||= ""

    new_body = prelude.rstrip + "\n\n" + addendum

    github_client.update_pull_request(
      self.repository.full_name,
      self.number,
      body: new_body
    )
  end

  def update_labels
    labels = generated_reviewers.map do |reviewer|
      reviewer.review_rule.name
    end
    labels = labels.uniq

    github_client.add_labels_to_an_issue(
      self.repository.full_name,
      self.number,
      labels
    )
  end

  private

  def update_child_pull_requests
    PullRequest.where(parent_pull_request_id: self.id).find_each do |child|
      child.status = self.status
      child.save!
      child.update_status
    end
  end

  def commit_status
    case self.status
    when "pending_review"
      "pending"
    when "approved"
      "success"
    else
      "failure"
    end
  end

  def commit_status_details(message = nil)
    if self.parent_pull_request
      desc = format(
        STATUS_DELEGATED,
        parent_number: self.parent_pull_request.number
      )

      {
        context: "code-review/cody",
        description: desc,
        target_url: self.parent_pull_request.html_url
      }
    else
      {
        context: "code-review/cody",
        description: COMMIT_STATUS_DESCRIPTIONS[commit_status] % message,
        target_url: self.target_url
      }
    end
  end
end
