class CreateDeviceSignIns < ActiveRecord::Migration[8.1]
  def change
    create_enum :device_sign_in_state, %w[pending approved used]

    create_table :device_sign_ins, id: :uuid do |t|
      t.references :user, type: :uuid, foreign_key: {on_delete: :cascade}
      t.string :code, null: false
      t.enum :state, enum_type: :device_sign_in_state, default: "pending", null: false
      t.string :user_agent
      t.datetime :expires_at, null: false
      t.timestamps

      t.index :code, unique: true, where: "state = 'pending'"
      t.index :expires_at
      t.check_constraint "state = 'pending' OR user_id IS NOT NULL", name: "check_device_sign_in_approved_by_user"
    end
  end
end
