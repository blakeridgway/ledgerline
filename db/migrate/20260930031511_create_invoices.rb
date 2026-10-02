class CreateInvoices < ActiveRecord::Migration[8.1]
  def change
    create_table :invoices do |t|
      t.references :user, null: false, foreign_key: true
      t.references :client, null: false, foreign_key: true
      t.string :number, null: false
      t.date :period_start, null: false
      t.date :period_end, null: false

      # "draft", "sent", "paid", or "void".
      t.string :status, null: false, default: "draft"
      t.date :issued_on
      t.date :due_on
      t.decimal :subtotal, precision: 10, scale: 2, null: false, default: 0
      t.decimal :total, precision: 10, scale: 2, null: false, default: 0
      t.text :notes
      t.datetime :paid_at

      t.timestamps
    end

    add_index :invoices, [ :user_id, :number ], unique: true
    add_index :invoices, [ :client_id, :period_start ]
  end
end
