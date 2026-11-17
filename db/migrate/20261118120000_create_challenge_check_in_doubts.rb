class CreateChallengeCheckInDoubts < ActiveRecord::Migration[8.1]
  def change
    create_enum :challenge_check_in_status, %w[counted disputed]

    add_column :challenge_check_ins, :status, :enum, enum_type: :challenge_check_in_status, default: "counted", null: false
    add_index :challenge_check_ins, :status

    create_table :challenge_check_in_doubts, id: :uuid do |t|
      t.references :challenge_check_in, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.references :user, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.string :note
      t.timestamps

      t.index [:challenge_check_in_id, :user_id], unique: true
      t.check_constraint "char_length(note) <= 140", name: "check_doubt_note_length"
    end
  end
end
