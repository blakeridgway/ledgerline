class CreateInvoiceLineItems < ActiveRecord::Migration[8.1]
  def change
    create_table :invoice_line_items do |t|
      t.references :invoice, null: false, foreign_key: true

      # Kept for traceability; null for flat monthly retainer lines.
      t.references :time_entry, null: true, foreign_key: true

      # "hourly" or "monthly".
      t.string :kind, null: false, default: "hourly"
      t.string :description, null: false
      t.decimal :quantity, precision: 10, scale: 2, null: false, default: 0
      t.decimal :unit_rate, precision: 10, scale: 2, null: false, default: 0
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0

      t.timestamps
    end
  end
end
