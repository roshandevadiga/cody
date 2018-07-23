class Types::QueryType < Types::BaseObject
  description "The query root"

  field :viewer, Types::UserType, null: true,
    description: "The currently authenticated user"

  def viewer
    Current.user
  end

  field :node, field: GraphQL::Relay::Node.field
  field :nodes, field: GraphQL::Relay::Node.plural_field
end
