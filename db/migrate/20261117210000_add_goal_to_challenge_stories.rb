class AddGoalToChallengeStories < ActiveRecord::Migration[8.1]
  def change
    create_enum :challenge_cadence, %w[daily weekly]
    create_enum :challenge_unit, %w[reps minutes km pages]
    create_enum :challenge_target_scope, %w[each_time total]

    change_table :challenge_stories, bulk: true do |t|
      t.enum :cadence, enum_type: :challenge_cadence, default: "daily", null: false
      t.integer :times_per_period, default: 1, null: false
      t.enum :unit, enum_type: :challenge_unit
      t.decimal :target_amount, precision: 10, scale: 2
      t.enum :target_scope, enum_type: :challenge_target_scope

      t.check_constraint "(cadence = 'daily' AND times_per_period = 1) OR (cadence = 'weekly' AND times_per_period BETWEEN 1 AND 6)", name: "check_times_per_period"
      t.check_constraint "(target_amount IS NULL) = (target_scope IS NULL)", name: "check_target_complete"
      t.check_constraint "target_amount IS NULL OR (unit IS NOT NULL AND target_amount > 0)", name: "check_target_needs_unit"
    end

    add_column :challenge_check_ins, :amount, :decimal, precision: 10, scale: 2
    add_check_constraint :challenge_check_ins, "amount IS NULL OR amount > 0", name: "check_amount_positive"
  end
end
