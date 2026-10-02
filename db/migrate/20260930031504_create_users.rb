class CreateUsers < ActiveRecord::Migration[8.1]
  def change
    create_table :users do |t|
      t.string :email_address, null: false
      t.string :password_digest, null: false

      # Business details used as the "from" block on invoices.
      t.string :name
      t.string :business_name
      t.string :phone
      t.text :address
      t.string :tax_id
      t.string :default_currency, null: false, default: "USD"
      t.integer :default_payment_terms_days, null: false, default: 30
      t.string :invoice_prefix, null: false, default: "INV"
      t.text :payment_instructions

      t.timestamps
    end
    add_index :users, :email_address, unique: true
  end
end
