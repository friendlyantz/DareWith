class AddEmailLoginCodeToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :email_login_code_digest, :string
    add_column :users, :email_login_code_attempts, :integer, default: 0, null: false
  end
end
