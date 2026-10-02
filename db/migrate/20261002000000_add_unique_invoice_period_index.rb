class AddUniqueInvoicePeriodIndex < ActiveRecord::Migration[8.1]
  # Exact duplicate periods are also blocked at the database so two concurrent
  # creates can't both win. (Overlap more generally is enforced in the model,
  # since SQLite has no exclusion constraint.)
  def change
    add_index :invoices, [ :client_id, :period_start, :period_end ],
      unique: true,
      where: "status != 'void'",
      name: "index_invoices_on_client_and_period_not_void"
  end
end
