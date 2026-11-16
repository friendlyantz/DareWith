class AddLastRecappedOnToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :last_recapped_on, :date
  end
end
