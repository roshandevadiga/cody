class Types::MutationType < Types::BaseObject
  description "The mutation root"

  field :update_user, field: Mutations::UpdateUser.field, null: true
end
