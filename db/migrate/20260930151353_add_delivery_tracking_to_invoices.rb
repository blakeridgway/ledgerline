class AddDeliveryTrackingToInvoices < ActiveRecord::Migration[8.1]
  def change
    # When the invoice was emailed to the client, and when we last chased it.
    add_column :invoices, :sent_at, :datetime
    add_column :invoices, :last_reminded_at, :datetime

    # Backs the overdue / due-soon lookups.
    add_index :invoices, [ :user_id, :status, :due_on ]
  end
end
