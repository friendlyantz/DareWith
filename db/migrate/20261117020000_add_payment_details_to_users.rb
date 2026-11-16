class AddPaymentDetailsToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :payment_details, :string
    add_check_constraint :users, "char_length(payment_details) <= 120", name: "check_user_payment_details_length"
  end
end
