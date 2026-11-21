class CreateNotifications < ActiveRecord::Migration[8.1]
  def change
    create_table :notifications, id: :uuid do |t|
      t.references :user, null: false, type: :uuid, index: false, foreign_key: {on_delete: :cascade}
      t.string :title, null: false
      t.string :body
      t.string :path, null: false, default: "/"
      t.datetime :read_at

      t.timestamps
    end

    add_index :notifications, [:user_id, :created_at]
    add_index :notifications, :user_id, where: "read_at IS NULL", name: "index_notifications_unread_on_user_id"
  end
end
