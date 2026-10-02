# Seeds create the account you sign in with, plus a small set of demo data the
# first time it runs. Override the credentials with environment variables:
#
#   SEED_EMAIL=me@example.com SEED_PASSWORD=secret bin/rails db:seed

email = ENV.fetch("SEED_EMAIL", "blake@example.com")
password = ENV.fetch("SEED_PASSWORD", "password123")

user = User.find_or_initialize_by(email_address: email)
user.assign_attributes(
  password: password,
  password_confirmation: password,
  name: ENV.fetch("SEED_NAME", "Blake"),
  business_name: ENV.fetch("SEED_BUSINESS", "Blake Consulting LLC"),
  phone: "512-555-0134",
  address: "1 Main St, Suite 200\nAustin, TX 78701",
  default_currency: "USD",
  default_payment_terms_days: 30,
  invoice_prefix: "INV",
  expected_hours_per_month: 160,
  payment_instructions: "ACH transfer: Chase Bank, routing 000000000, account 000000000.\n" \
                        "Please reference the invoice number on all payments."
)
user.save!
puts "Account ready: #{user.email_address} (password: #{password})"

if user.clients.none?
  hourly_clients = [
    { name: "Northwind Analytics", email: "ap@northwind.example", hourly_rate: 165,
      notes: "Net 30. Submit invoices through their vendor portal." },
    { name: "Harborline Studio", email: "billing@harborline.example", hourly_rate: 140 }
  ]

  hourly_clients.each do |attributes|
    client = user.clients.create!(
      attributes.merge(billing_type: "hourly", currency: "USD", active: true)
    )

    6.times do |week|
      next if week.zero? && client.name.start_with?("Harborline")

      client.time_entries.create!(
        worked_on: (week + 1).weeks.ago.to_date,
        hours: [ 2.5, 3.75, 6.0, 1.25 ].sample,
        description: [
          "Data pipeline review",
          "Weekly planning call",
          "Dashboard implementation",
          "Schema migration and backfill",
          "Client sync + notes"
        ].sample,
        billable: true
      )
    end
  end

  retainer = user.clients.create!(
    name: "Vertex Robotics",
    company: "Finance",
    email: "finance@vertex.example",
    billing_type: "monthly",
    monthly_rate: 6000,
    expected_hours_per_month: 160,
    currency: "USD",
    active: true,
    notes: "Flat retainer: 160 hours a month, timesheet submitted with each invoice."
  )

  # A realistic full-time month: 8 hours for every weekday up to yesterday, so
  # the retainer shows progress against its 160-hour commitment.
  workdays = (Date.current.beginning_of_month..(Date.current - 1.day)).select(&:on_weekday?)
  descriptions = [
    "Platform development",
    "Code review and pairing",
    "Data pipeline work",
    "Client sync and planning",
    "Support and bug fixes"
  ]

  workdays.each_with_index do |day, index|
    retainer.time_entries.create!(
      worked_on: day,
      hours: 8,
      description: descriptions[index % descriptions.size],
      billable: true
    )
  end

  puts "Created #{user.clients.count} demo clients and #{user.time_entries.count} time entries."
end

if user.expenses.none?
  # Spread a few costs across the year so the profit report isn't empty.
  span = (Date.current - Date.current.beginning_of_year).to_i
  offsets = [ 0.10, 0.25, 0.45, 0.65, 0.85 ].map { |fraction| (span * fraction).round }

  [
    { vendor: "Figma", category: "Software and subscriptions", amount: 45 },
    { vendor: "Chase", category: "Commissions and fees", amount: 18.75, notes: "Wire fees" },
    { vendor: "Delta", category: "Travel", amount: 412.30, client: user.clients.find_by(name: "Northwind Analytics") },
    { vendor: "Blue Cross", category: "Insurance", amount: 640 },
    { vendor: "Apple", category: "Office expense", amount: 1299, notes: "MacBook Pro" }
  ].each_with_index do |attributes, index|
    user.expenses.create!(
      attributes.merge(spent_on: Date.current.beginning_of_year + offsets[index].days)
    )
  end

  puts "Created #{user.expenses.count} demo expenses."
end

if user.invoices.none?
  # A paid invoice and an overdue one, so the reports and the chasing views have
  # something real to show.
  retainer = user.clients.monthly.order(:id).first

  if retainer
    last_month = Date.current.prev_month
    paid_invoice = InvoiceBuilder.new(
      client: retainer,
      period_start: last_month.beginning_of_month,
      period_end: last_month.end_of_month,
      issued_on: last_month.end_of_month
    ).call
    paid_invoice.mark_paid!(last_month.end_of_month + 12.days)

    older = last_month.prev_month
    overdue_invoice = InvoiceBuilder.new(
      client: retainer,
      period_start: older.beginning_of_month,
      period_end: older.end_of_month,
      issued_on: older.end_of_month
    ).call
    # Sent the day after it was issued, so the history reads coherently.
    overdue_invoice.update!(status: "sent", sent_at: older.end_of_month + 1.day)

    puts "Created demo invoices: #{paid_invoice.number} (paid), " \
         "#{overdue_invoice.number} (sent, now overdue)."
  end
end
