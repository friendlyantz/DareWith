class CreateChallengeCheckInReplies < ActiveRecord::Migration[8.1]
  def change
    create_table :challenge_check_in_replies, id: :uuid do |t|
      t.references :challenge_check_in, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.references :user, type: :uuid, null: false, foreign_key: {on_delete: :cascade}
      t.text :body, null: false
      t.timestamps

      t.index [:challenge_check_in_id, :created_at]
      t.check_constraint "char_length(body) BETWEEN 1 AND 280", name: "check_reply_body_length"
    end

    add_column :challenge_check_ins, :challenge_check_in_replies_count, :integer, default: 0, null: false
    add_column :users, :challenge_check_in_replies_count, :integer, default: 0, null: false
  end
end
