class AllowSeveralCheckInsADay < ActiveRecord::Migration[8.1]
  def change
    remove_index :challenge_check_ins, [:challenge_participant_id, :checked_in_on], unique: true, name: "idx_on_challenge_participant_id_checked_in_on_b71ead7892"
    add_index :challenge_check_ins, [:challenge_participant_id, :checked_in_on]
  end
end
