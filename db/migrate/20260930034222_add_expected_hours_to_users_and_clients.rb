class AddExpectedHoursToUsersAndClients < ActiveRecord::Migration[8.1]
  def change
    # Default retainer commitment, e.g. 160 for a full-time 1099 arrangement.
    add_column :users, :expected_hours_per_month, :decimal, precision: 6, scale: 2, null: false, default: 0
    # Per-client override; 0 means "no commitment tracked".
    add_column :clients, :expected_hours_per_month, :decimal, precision: 6, scale: 2, null: false, default: 0
  end
end
