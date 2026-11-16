class AddBackedUpToCredentials < ActiveRecord::Migration[8.1]
  def change
    # Unknown (nil) until the passkey's next sign-in reports it
    add_column :credentials, :backed_up, :boolean
  end
end
