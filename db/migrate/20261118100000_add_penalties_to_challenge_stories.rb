class AddPenaltiesToChallengeStories < ActiveRecord::Migration[8.1]
  def change
    create_enum :challenge_penalty_mode, %w[per_miss most_misses]
    create_enum :challenge_reward_kind, %w[pledge penalty]

    change_table :challenge_stories, bulk: true do |t|
      t.enum :penalty_mode, enum_type: :challenge_penalty_mode
      t.string :penalty

      t.check_constraint "(penalty_mode IS NULL) = (penalty IS NULL)", name: "check_penalty_complete"
      t.check_constraint "char_length(penalty) <= 100", name: "check_penalty_length"
    end

    add_column :challenge_rewards, :kind, :enum, enum_type: :challenge_reward_kind, default: "pledge", null: false
    add_index :challenge_rewards, :kind

    # Someone can pledge a friend a reward and also owe them a penalty
    remove_index :challenge_rewards, [:giver_id, :receiver_id, :challenge_story_id], name: "index_challenge_rewards_on_participants_and_story", unique: true
    add_index :challenge_rewards, [:giver_id, :receiver_id, :challenge_story_id, :kind], name: "index_challenge_rewards_on_participants_story_and_kind", unique: true
  end
end
