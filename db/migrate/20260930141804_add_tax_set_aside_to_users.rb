class AddTaxSetAsideToUsers < ActiveRecord::Migration[8.1]
  def change
    # Percentage of net profit to hold back for quarterly estimated taxes.
    add_column :users, :tax_set_aside_percent, :decimal, precision: 5, scale: 2, null: false, default: 30
  end
end
