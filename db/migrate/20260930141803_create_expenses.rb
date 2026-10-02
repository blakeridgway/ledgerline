class CreateExpenses < ActiveRecord::Migration[8.1]
  def change
    create_table :expenses do |t|
      t.references :user, null: false, foreign_key: true

      # Optional: tag an expense to a client (useful for reports, not billing).
      t.references :client, null: true, foreign_key: true

      t.date :spent_on, null: false
      t.string :vendor, null: false
      t.string :category, null: false
      t.decimal :amount, precision: 10, scale: 2, null: false, default: 0
      t.text :notes

      t.timestamps
    end

    add_index :expenses, [ :user_id, :spent_on ]
    add_index :expenses, [ :user_id, :category ]
  end
end
