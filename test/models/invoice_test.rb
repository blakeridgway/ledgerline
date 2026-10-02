require "test_helper"

class InvoiceTest < ActiveSupport::TestCase
  setup do
    @user = users(:blake)
    @client = clients(:acme)
  end

  test "is valid with the fixture data" do
    assert invoices(:acme_old_paid).valid?
  end

  test "next_number_for starts a fresh monthly sequence" do
    expected = "INV-#{Date.current.strftime('%Y%m')}-001"

    assert_equal expected, Invoice.next_number_for(@user)
  end

  test "next_number_for increments within the same month" do
    number = Invoice.next_number_for(@user)
    @user.invoices.create!(
      client: @client, number: number,
      period_start: Date.current, period_end: Date.current,
      issued_on: Date.current
    )

    assert_equal "INV-#{Date.current.strftime('%Y%m')}-002", Invoice.next_number_for(@user)
  end

  test "next_number_for uses the owner's prefix" do
    expected = "SAM-#{Date.current.strftime('%Y%m')}-001"

    assert_equal expected, Invoice.next_number_for(users(:other))
  end

  test "numbers are unique per user" do
    duplicate = @user.invoices.new(
      client: @client, number: invoices(:acme_old_paid).number,
      period_start: Date.current, period_end: Date.current
    )

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:number], "has already been taken"
  end

  test "rejects a period that ends before it starts" do
    invoice = @user.invoices.new(
      client: @client, number: "INV-TEST-1",
      period_start: Date.current, period_end: Date.current - 1.day
    )

    assert_not invoice.valid?
    assert_includes invoice.errors[:period_end], "must be on or after the period start"
  end

  test "requires an issue date" do
    invoice = @user.invoices.new(
      client: @client, number: "INV-TEST-ISSUE",
      period_start: Date.current, period_end: Date.current
    )

    assert_not invoice.valid?
    assert_includes invoice.errors[:issued_on], "can't be blank"
  end

  test "rejects a period that overlaps an existing non-void invoice" do
    existing = invoices(:acme_old_draft)
    overlapping = existing.client.invoices.new(
      user: @user, number: "INV-OVERLAP-1",
      period_start: Date.new(2020, 2, 15), period_end: Date.new(2020, 3, 10),
      issued_on: Date.current
    )

    assert_not overlapping.valid?
    assert_includes overlapping.errors[:base], "An invoice already exists for an overlapping period"
  end

  test "allows a period adjacent to an existing invoice" do
    existing = invoices(:acme_old_draft)
    adjacent = existing.client.invoices.new(
      user: @user, number: "INV-ADJACENT-1",
      period_start: Date.new(2020, 3, 1), period_end: Date.new(2020, 3, 31),
      issued_on: Date.current
    )

    assert adjacent.valid?, adjacent.errors.full_messages.to_sentence
  end

  test "allows re-invoicing a period once the existing invoice is void" do
    existing = invoices(:acme_old_draft)
    existing.void!
    reuse = existing.client.invoices.new(
      user: @user, number: "INV-REUSE-1",
      period_start: existing.period_start, period_end: existing.period_end,
      issued_on: Date.current
    )

    assert reuse.valid?, reuse.errors.full_messages.to_sentence
  end

  test "the database rejects an exact duplicate period when validations are bypassed" do
    existing = invoices(:acme_old_draft)
    duplicate = existing.client.invoices.new(
      user: existing.user, number: "INV-DUP-1",
      period_start: existing.period_start, period_end: existing.period_end,
      issued_on: Date.current
    )

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "mark_paid! records the payment" do
    invoice = invoices(:acme_old_draft)
    invoice.mark_paid!(Date.new(2026, 3, 15))

    assert invoice.paid?
    assert_equal Date.new(2026, 3, 15), invoice.paid_at.to_date
    assert_not invoice.outstanding?
  end

  test "hours_total only counts hourly lines" do
    assert_equal 8.to_d, invoices(:acme_old_paid).hours_total
  end

  test "destroying an invoice releases its time entries" do
    entry = time_entries(:acme_unbilled_a)
    entry.update!(invoice: invoices(:acme_old_paid))

    invoices(:acme_old_paid).destroy

    assert_nil entry.reload.invoice_id
  end

  test "period_label formats the range" do
    assert_equal "Feb 1, 2020 – Feb 29, 2020", invoices(:acme_old_draft).period_label
  end

  test "next_period advances one calendar month for a monthly period" do
    invoice = @user.invoices.new(
      client: @client,
      period_start: Date.new(2026, 9, 1), period_end: Date.new(2026, 9, 30)
    )

    assert invoice.calendar_month?
    # September is 30 days, October is 31 — a naive same-length shift gets this wrong.
    assert_equal [ Date.new(2026, 10, 1), Date.new(2026, 10, 31) ], invoice.next_period
  end

  test "next_period handles a leap February" do
    invoice = @user.invoices.new(
      client: @client,
      period_start: Date.new(2028, 2, 1), period_end: Date.new(2028, 2, 29)
    )

    assert invoice.calendar_month?
    assert_equal [ Date.new(2028, 3, 1), Date.new(2028, 3, 31) ], invoice.next_period
  end

  test "next_period keeps the length of a non-month period" do
    invoice = @user.invoices.new(
      client: @client,
      period_start: Date.new(2026, 3, 10), period_end: Date.new(2026, 3, 20)
    )

    assert_not invoice.calendar_month?
    assert_equal [ Date.new(2026, 3, 21), Date.new(2026, 3, 31) ], invoice.next_period
  end

  test "next_period crosses the year boundary" do
    invoice = @user.invoices.new(
      client: @client,
      period_start: Date.new(2026, 12, 1), period_end: Date.new(2026, 12, 31)
    )

    assert_equal [ Date.new(2027, 1, 1), Date.new(2027, 1, 31) ], invoice.next_period
  end

  # --- Chasing payment -----------------------------------------------------

  test "a sent invoice past its due date is overdue" do
    invoice = invoices(:acme_overdue)

    assert invoice.overdue?
    assert_operator invoice.days_overdue, :>, 0
  end

  test "drafts and paid invoices are never overdue" do
    assert_not invoices(:acme_old_draft).overdue?
    assert_not invoices(:acme_old_paid).overdue?
    assert_equal 0, invoices(:acme_old_draft).days_overdue
  end

  test "an invoice due today is not yet overdue" do
    invoice = invoices(:acme_overdue)
    invoice.update!(due_on: Date.current)

    assert_not invoice.overdue?
    assert_equal 0, invoice.days_until_due
    assert invoice.due_soon?
  end

  test "due_soon covers the next week" do
    invoice = invoices(:acme_overdue)
    invoice.update!(due_on: Date.current + 3.days)

    assert invoice.due_soon?
    assert_equal 3, invoice.days_until_due
    assert_not invoice.due_soon?(1.day)
  end

  test "mark_sent! records the send time and moves a draft to sent" do
    invoice = invoices(:acme_old_draft)
    invoice.mark_sent!(Time.zone.local(2026, 3, 1, 9, 30))

    assert invoice.sent?
    assert_equal Date.new(2026, 3, 1), invoice.sent_at.to_date
  end

  test "mark_sent! leaves an already sent invoice sent" do
    invoice = invoices(:acme_overdue)
    sent_at = invoice.sent_at

    invoice.mark_sent!

    assert invoice.sent?
    assert_not_equal sent_at, invoice.reload.sent_at
  end

  test "overdue scope finds only late sent invoices" do
    overdue = @user.invoices.overdue

    assert_includes overdue, invoices(:acme_overdue)
    assert_not_includes overdue, invoices(:acme_old_draft)
    assert_not_includes overdue, invoices(:acme_old_paid)
  end

  test "awaiting_payment scope is everything sent and unpaid" do
    assert_includes @user.invoices.awaiting_payment, invoices(:acme_overdue)
    assert_not_includes @user.invoices.awaiting_payment, invoices(:acme_old_draft)
  end
end
