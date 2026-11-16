class AddCheckedInOnToChallengeCheckIns < ActiveRecord::Migration[8.1]
  def up
    add_column :challenge_check_ins, :checked_in_on, :date

    execute <<~SQL
      UPDATE challenge_check_ins
      SET checked_in_on = ((challenge_check_ins.created_at AT TIME ZONE 'UTC') AT TIME ZONE users.time_zone)::date
      FROM challenge_participants, users
      WHERE challenge_participants.id = challenge_check_ins.challenge_participant_id
        AND users.id = challenge_participants.user_id
    SQL
    execute "UPDATE challenge_check_ins SET checked_in_on = created_at::date WHERE checked_in_on IS NULL"

    remove_extra_check_ins_on_the_same_day

    change_column_null :challenge_check_ins, :checked_in_on, false
    add_index :challenge_check_ins, [:challenge_participant_id, :checked_in_on], unique: true
  end

  def down
    remove_column :challenge_check_ins, :checked_in_on
  end

  private

  # Test data from before the one-check-in-a-day rule; keeps the earliest check-in of each day
  def remove_extra_check_ins_on_the_same_day
    extras = <<~SQL
      SELECT id FROM (
        SELECT id, row_number() OVER (PARTITION BY challenge_participant_id, checked_in_on ORDER BY created_at) AS position
        FROM challenge_check_ins
      ) ranked
      WHERE position > 1
    SQL

    execute "DELETE FROM active_storage_attachments WHERE record_type = 'ChallengeCheckIn' AND record_id IN (#{extras})"
    execute "DELETE FROM challenge_check_ins WHERE id IN (#{extras})"

    execute <<~SQL
      UPDATE challenge_participants
      SET challenge_check_ins_count = (SELECT count(*) FROM challenge_check_ins WHERE challenge_participant_id = challenge_participants.id)
    SQL
    execute <<~SQL
      UPDATE challenge_stories
      SET challenge_check_ins_count = (SELECT count(*) FROM challenge_check_ins WHERE challenge_story_id = challenge_stories.id)
    SQL
  end
end
