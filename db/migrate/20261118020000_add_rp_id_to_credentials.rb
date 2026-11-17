class AddRpIdToCredentials < ActiveRecord::Migration[8.1]
  # Production passkeys so far were made on strivo.me, before the move to darewith.app.
  # The default also keeps older app versions working if a deploy is rolled back:
  # they don't know this column, and the passkeys they make are strivo.me ones.
  def change
    previous_rp_id = Rails.env.production? ? "strivo.me" : WebAuthn.configuration.rp_id
    add_column :credentials, :rp_id, :string, null: false, default: previous_rp_id
    add_index :credentials, [:user_id, :rp_id]
  end
end
