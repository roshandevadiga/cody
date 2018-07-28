class Types::RepositoryType < Types::BaseObject

  implements GraphQL::Relay::Node.interface

  global_id_field :id

  field :owner, String, null: false
  field :name, String, null: false

  field :pull_requests, Types::PullRequestType.connection_type, null: true, connection: true do # rubocop:disable Metrics/LineLength
    description "This reapository's Pull Requests"
    argument :status, String, required: false
  end

  def pull_requests(**args)
    @object.pull_requests.order("created_at DESC")
  end

  field :pull_request, Types::PullRequestType, null: true do
    description "Find a PullRequest by number"
    argument :number, String, required: true
  end

  def pull_request(**args)
    @object.pull_requests.find_by(number: args[:number])
  end

  field :review_rules, Types::ReviewRuleType.connection_type, null: true, connection: true do # rubocop:disable Metrics/LineLength
    description "This repository's review rules"
  end

  def review_rules
    @object.review_rules
  end

  field :review_rule, Types::ReviewRuleType, null: true do
    description "Find a Review Rule by code"
    argument :short_code, String, required: true
  end

  def review_rule(**args)
    @object.review_rules.find_by(short_code: args[:short_code])
  end
end
