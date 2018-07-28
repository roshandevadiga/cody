class Types::UserType < Types::BaseObject

  implements GraphQL::Relay::Node.interface

  global_id_field :id

  field :login, String, null: false,
    description: "The user's login"
  field :email, String, null: true,
    description: "The user's email"
  field :name, String, null: false,
    description: "The user's name"
  field :send_new_reviews_summary, Boolean, null: false,
    description: "Opt-in choice for daily code review summary email"

  def send_new_reviews_summary
    !!@object.send_new_reviews_summary?
  end

  field :repositories, Types::RepositoryType.connection_type, null: true,
    connection: true

  def repositories
    Pundit.policy_scope(@object, Repository)
  end

  field :repository, Types::RepositoryType, null: true do
    description "Find a given repository by the owner and name"
    argument :owner, String, required: true
    argument :name, String, required: true
  end

  def repository(**args)
    Pundit.policy_scope(@object, Repository)
      .find_by(owner: args[:owner], name: args[:name])
  end
end
