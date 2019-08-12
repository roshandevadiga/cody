class CreateCommandInvocations < ActiveRecord::Migration[5.1]
  def change
    create_table :command_invocations do |t|
      t.string :command
      t.string :args
      t.string :login
      t.references :pull_request, foreign_key: true, index: true, null: false

      t.timestamps
    end
  end
end
