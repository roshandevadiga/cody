class Types::ReviewerType < Types::BaseObject

  implements GraphQL::Relay::Node.interface

  global_id_field :id

  field :login, String, null: false
  field :status, String, null: false

  field :review_rule, Types::ReviewRuleType,
    description: "The Review Rule that added this Reviewer",
    null: true

  def review_rule
    @object.review_rule
  end

  VersionType = GraphQL::ObjectType.define do
    name "ReviewerVersion"

    field :login, function: Functions::HashField.new(
      "login",
      types[types.String]
    )

    field :status, function: Functions::HashField.new(
      "status",
      types[types.String]
    )
  end

  field :versions, [VersionType, null: true], null: true

  def versions
    @object.versions.map(&:changeset)
  end
end
