# Targets used to be per check-in. Now they're per day or per week, and a week's check-ins add up,
# so a weekly "3× a week, 5 km each time" becomes "15 km a week".
class MakeTargetsPerPeriod < ActiveRecord::Migration[8.1]
  def up
    rename_enum_value :challenge_target_scope, from: "each_time", to: "each_period"
    execute <<~SQL
      UPDATE challenge_stories SET target_amount = target_amount * times_per_period
      WHERE cadence = 'weekly' AND target_scope = 'each_period'
    SQL
  end

  def down
    execute <<~SQL
      UPDATE challenge_stories SET target_amount = target_amount / times_per_period
      WHERE cadence = 'weekly' AND target_scope = 'each_period'
    SQL
    rename_enum_value :challenge_target_scope, from: "each_period", to: "each_time"
  end
end
