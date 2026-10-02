class CreateClients < ActiveRecord::Migration[8.1]
  def change
    create_table :clients do |t|
      t.references :user, null: false, foreign_key: true
      t.string :name, null: false
      t.string :company
      t.string :email
      t.string :phone
      t.text :address

      # "hourly" bills by tracked hours, "monthly" bills a flat retainer.
      t.string :billing_type, null: false, default: "hourly"
      t.decimal :hourly_rate, precision: 10, scale: 2, null: false, default: 0
      t.decimal :monthly_rate, precision: 10, scale: 2, null: false, default: 0
      t.string :currency, null: false, default: "USD"
      t.boolean :active, null: false, default: true
      t.text :notes

      t.timestamps
    end

    add_index :clients, [ :user_id, :name ], unique: true
  end
end
