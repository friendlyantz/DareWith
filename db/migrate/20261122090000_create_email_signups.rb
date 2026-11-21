class CreateEmailSignups < ActiveRecord::Migration[8.1]
  def change
    create_table :email_signups, id: :uuid do |t|
      t.string :email, null: false
      t.string :code_digest, null: false
      t.integer :code_attempts, null: false, default: 0
      t.datetime :code_sent_at, null: false

      t.timestamps
    end

    add_index :email_signups, :email, unique: true
    add_check_constraint :email_signups, "email = lower(btrim(email))", name: "email_signups_email_normalized"
  end
end
