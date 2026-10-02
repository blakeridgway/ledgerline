class CreateTimeEntries < ActiveRecord::Migration[8.1]
  def change
    create_table :time_entries do |t|
      t.references :client, null: false, foreign_key: true
      t.date :worked_on, null: false
      t.decimal :hours, precision: 6, scale: 2, null: false, default: 0
      t.text :description
      t.boolean :billable, null: false, default: true

      # Set once the entry has been pulled onto an invoice.
      t.references :invoice, null: true, foreign_key: true

      t.timestamps
    end

    add_index :time_entries, [ :client_id, :worked_on ]
    add_index :time_entries, [ :invoice_id, :worked_on ]
  end
end
