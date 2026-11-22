class AddVerifiedAtToEmailSignups < ActiveRecord::Migration[8.1]
  def change
    add_column :email_signups, :verified_at, :datetime
  end
end
