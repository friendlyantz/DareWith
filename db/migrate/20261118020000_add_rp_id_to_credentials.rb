class AddRpIdToCredentials < ActiveRecord::Migration[8.1]
  # Production passkeys so far were made on strivo.me, before the move to darewith.app
  def up
    add_column :credentials, :rp_id, :string
    previous_rp_id = Rails.env.production? ? "strivo.me" : WebAuthn.configuration.rp_id
    execute "UPDATE credentials SET rp_id = #{connection.quote(previous_rp_id)}"
    change_column_null :credentials, :rp_id, false
    add_index :credentials, [:user_id, :rp_id]
  end

  def down
    remove_column :credentials, :rp_id
  end
end
