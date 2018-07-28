class Types::PullRequestType < Types::BaseObject

  implements GraphQL::Relay::Node.interface

  global_id_field :id

  field :number, String, null: false
  field :repository, String, null: false

  def repository
    @object.repository.full_name
  end
  field :status, String, null: false

  field :reviewers, Types::ReviewerType.connection_type, null: true, connection: true do # rubocop:disable Metrics/LineLength
    argument :status, String, required: false
  end

  def reviewers(**args)
    case args[:status]
    when Reviewer::STATUS_PENDING_APPROVAL
      @object.reviewers.pending_review
    when Reviewer::STATUS_APPROVED
      @object.reviewers.completed_review
    else
      @object.reviewers
    end
  end
end
