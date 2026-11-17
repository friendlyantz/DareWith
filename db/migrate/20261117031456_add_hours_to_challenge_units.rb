class AddHoursToChallengeUnits < ActiveRecord::Migration[8.1]
  def up
    add_enum_value :challenge_unit, "hours", after: "minutes"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Postgres can't drop an enum value"
  end
end
