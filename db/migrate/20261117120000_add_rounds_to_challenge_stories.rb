class AddRoundsToChallengeStories < ActiveRecord::Migration[8.1]
  def change
    add_reference :challenge_stories, :previous_challenge_story, type: :uuid,
      foreign_key: {to_table: :challenge_stories, on_delete: :nullify},
      index: {unique: true}
    add_column :challenge_stories, :round, :integer, default: 1, null: false
    add_check_constraint :challenge_stories, "round >= 1", name: "check_round_positive"
  end
end
