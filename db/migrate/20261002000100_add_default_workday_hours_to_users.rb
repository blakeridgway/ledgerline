class AddDefaultWorkdayHoursToUsers < ActiveRecord::Migration[8.1]
  def change
    add_column :users, :default_workday_hours, :decimal,
      precision: 4, scale: 2, default: 8.0, null: false
  end
end
