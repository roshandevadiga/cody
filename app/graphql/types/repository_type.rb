class Types::RepositoryType < Types::BaseObject

  implements GraphQL::Relay::Node.interface

  global_id_field :id

  field :owner, String, null: false
  field :name, String, null: false

  field :pull_requests, Types::PullRequestType.connection_type, description: "This repository's Pull Requests", null: true, connection: true do
    argument :status, String, required: false
  end

  def pull_requests(**args)
    @object.pull_requests.order("created_at DESC")
  end

  field :pull_request, Types::PullRequestType, description: "Find a PullRequest by number", null: true do
    argument :number, String, required: true
  end

  def pull_request(**args)
    @object.pull_requests.find_by(number: args[:number])
  end

  field :review_rules, Types::ReviewRuleType.connection_type, description: "This repository's review rules", null: true, connection: true

  def review_rules
    @object.review_rules
  end

  field :review_rule, Types::ReviewRuleType, description: "Find a Review Rule by code", null: true do
    argument :short_code, String, required: true
  end

  def review_rule(**args)
    @object.review_rules.find_by(short_code: args[:short_code])
  end
end
