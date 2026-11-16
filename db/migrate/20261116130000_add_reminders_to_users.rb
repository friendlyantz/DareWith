class AddRemindersToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :time_zone, :string, null: false, default: "UTC"
    add_column :users, :reminder_hour, :integer, default: 19
    add_column :users, :last_reminded_on, :date

    add_check_constraint :users, "reminder_hour BETWEEN 0 AND 23", name: "check_user_reminder_hour_range"
  end
end
