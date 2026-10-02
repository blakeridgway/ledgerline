# This file is auto-generated from the current state of the database. Instead
# of editing this file, please use the migrations feature of Active Record to
# incrementally modify your database, and then regenerate this schema definition.
#
# This file is the source Rails uses to define your schema when running `bin/rails
# db:schema:load`. When creating a new database, `bin/rails db:schema:load` tends to
# be faster and is potentially less error prone than running all of your
# migrations from scratch. Old migrations may fail to apply correctly if those
# migrations use external dependencies or application code.
#
# It's strongly recommended that you check this file into your version control system.

ActiveRecord::Schema[8.1].define(version: 2026_10_02_000101) do
  create_table "clients", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "name", null: false
    t.string "company"
    t.string "email"
    t.string "phone"
    t.text "address"
    t.string "billing_type", default: "hourly", null: false
    t.decimal "hourly_rate", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "monthly_rate", precision: 10, scale: 2, default: "0.0", null: false
    t.string "currency", default: "USD", null: false
    t.boolean "active", default: true, null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "expected_hours_per_month", precision: 6, scale: 2, default: "0.0", null: false
    t.index ["user_id", "name"], name: "index_clients_on_user_id_and_name", unique: true
    t.index ["user_id"], name: "index_clients_on_user_id"
  end

  create_table "expenses", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "client_id"
    t.date "spent_on", null: false
    t.string "vendor", null: false
    t.string "category", null: false
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["client_id"], name: "index_expenses_on_client_id"
    t.index ["user_id", "category"], name: "index_expenses_on_user_id_and_category"
    t.index ["user_id", "spent_on"], name: "index_expenses_on_user_id_and_spent_on"
    t.index ["user_id"], name: "index_expenses_on_user_id"
  end

  create_table "invoice_line_items", force: :cascade do |t|
    t.integer "invoice_id", null: false
    t.integer "time_entry_id"
    t.string "kind", default: "hourly", null: false
    t.string "description", null: false
    t.decimal "quantity", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "unit_rate", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "amount", precision: 10, scale: 2, default: "0.0", null: false
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["invoice_id"], name: "index_invoice_line_items_on_invoice_id"
    t.index ["time_entry_id"], name: "index_invoice_line_items_on_time_entry_id"
  end

  create_table "invoices", force: :cascade do |t|
    t.integer "user_id", null: false
    t.integer "client_id", null: false
    t.string "number", null: false
    t.date "period_start", null: false
    t.date "period_end", null: false
    t.string "status", default: "draft", null: false
    t.date "issued_on"
    t.date "due_on"
    t.decimal "subtotal", precision: 10, scale: 2, default: "0.0", null: false
    t.decimal "total", precision: 10, scale: 2, default: "0.0", null: false
    t.text "notes"
    t.datetime "paid_at"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.datetime "sent_at"
    t.datetime "last_reminded_at"
    t.index ["client_id", "period_start", "period_end"], name: "index_invoices_on_client_and_period_not_void", unique: true, where: "status != 'void'"
    t.index ["client_id", "period_start"], name: "index_invoices_on_client_id_and_period_start"
    t.index ["client_id"], name: "index_invoices_on_client_id"
    t.index ["user_id", "number"], name: "index_invoices_on_user_id_and_number", unique: true
    t.index ["user_id", "status", "due_on"], name: "index_invoices_on_user_id_and_status_and_due_on"
    t.index ["user_id"], name: "index_invoices_on_user_id"
  end

  create_table "sessions", force: :cascade do |t|
    t.integer "user_id", null: false
    t.string "ip_address"
    t.string "user_agent"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.index ["user_id"], name: "index_sessions_on_user_id"
  end

  create_table "time_entries", force: :cascade do |t|
    t.integer "client_id", null: false
    t.date "worked_on", null: false
    t.decimal "hours", precision: 6, scale: 2, default: "0.0", null: false
    t.text "description"
    t.boolean "billable", default: true, null: false
    t.integer "invoice_id"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.integer "break_minutes", default: 0, null: false
    t.index ["client_id", "worked_on"], name: "index_time_entries_on_client_id_and_worked_on"
    t.index ["client_id"], name: "index_time_entries_on_client_id"
    t.index ["invoice_id", "worked_on"], name: "index_time_entries_on_invoice_id_and_worked_on"
    t.index ["invoice_id"], name: "index_time_entries_on_invoice_id"
  end

  create_table "users", force: :cascade do |t|
    t.string "email_address", null: false
    t.string "password_digest", null: false
    t.string "name"
    t.string "business_name"
    t.string "phone"
    t.text "address"
    t.string "tax_id"
    t.string "default_currency", default: "USD", null: false
    t.integer "default_payment_terms_days", default: 30, null: false
    t.string "invoice_prefix", default: "INV", null: false
    t.text "payment_instructions"
    t.datetime "created_at", null: false
    t.datetime "updated_at", null: false
    t.decimal "expected_hours_per_month", precision: 6, scale: 2, default: "0.0", null: false
    t.decimal "tax_set_aside_percent", precision: 5, scale: 2, default: "30.0", null: false
    t.decimal "default_workday_hours", precision: 4, scale: 2, default: "8.0", null: false
    t.index ["email_address"], name: "index_users_on_email_address", unique: true
  end

  add_foreign_key "clients", "users"
  add_foreign_key "expenses", "clients"
  add_foreign_key "expenses", "users"
  add_foreign_key "invoice_line_items", "invoices"
  add_foreign_key "invoice_line_items", "time_entries"
  add_foreign_key "invoices", "clients"
  add_foreign_key "invoices", "users"
  add_foreign_key "sessions", "users"
  add_foreign_key "time_entries", "clients"
  add_foreign_key "time_entries", "invoices"
end
