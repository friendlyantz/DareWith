class CreateChallengeNudges < ActiveRecord::Migration[8.1]
  def change
    create_table :challenge_nudges, id: :uuid do |t|
      t.references :sender, null: false, type: :uuid, foreign_key: {to_table: :challenge_participants, on_delete: :cascade}
      t.references :receiver, null: false, type: :uuid, foreign_key: {to_table: :challenge_participants, on_delete: :cascade}
      t.date :nudged_on, null: false

      t.timestamps
    end

    add_index :challenge_nudges, [:sender_id, :receiver_id, :nudged_on], unique: true
    add_index :challenge_nudges, [:receiver_id, :nudged_on]
    add_check_constraint :challenge_nudges, "sender_id <> receiver_id", name: "check_nudge_not_self"
  end
end
