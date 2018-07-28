class Types::ReviewRuleType < Types::BaseObject

  implements GraphQL::Relay::Node.interface

  global_id_field :id

  field :name, String, "The rule's name", null: false
  field :short_code, String,
    description: "Short code identifying the rule in commands",
    null: false

  def short_code
    @object.short_code
  end
  field :type, String, "The rule's type", null: false
  field :reviewer, String, "The reviewer assigned to this rule", null: false

  def reviewer
    @object.reviewer_human_name
  end

  field :repository, String, "The repository that owns this rule", null: false
  field :match, String, "The criteria used to match this rule", null: false

  def match
    case @object
    when ReviewRuleAlways
      true
    else
      @object.file_match
    end
  end
end
