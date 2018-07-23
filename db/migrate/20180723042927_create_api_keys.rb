class CreateApiKeys < ActiveRecord::Migration[5.1]
  def change
    enable_extension("pgcrypto") unless extension_enabled?("pgcrypto")

    create_table :api_keys, id: :uuid, default: "gen_random_uuid()" do |t|
      t.references :user, foreign_key: true
      t.string :password_digest
    end
  end
end
