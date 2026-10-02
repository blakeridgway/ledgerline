require "test_helper"

class InvoiceBuilderTest < ActiveSupport::TestCase
  setup do
    @acme = clients(:acme)
    @period_start = Date.current.beginning_of_month
    @period_end = Date.current.end_of_month
  end

  def build(client: @acme, period_start: @period_start, period_end: @period_end, **options)
    InvoiceBuilder.new(
      client: client,
      period_start: period_start,
      period_end: period_end,
      issued_on: options.fetch(:issued_on, Date.current),
      notes: options[:notes]
    ).call
  end

  # --- hourly -------------------------------------------------------------

  test "creates one line item per unbilled entry" do
    invoice = build

    assert_equal 2, invoice.invoice_line_items.count
    assert_equal [ "Discovery workshop", "Data model review" ], invoice.invoice_line_items.map(&:description)
    assert invoice.invoice_line_items.all?(&:hourly?)
  end

  test "totals hours times the client rate" do
    invoice = build

    assert_equal 900.to_d, invoice.subtotal
    assert_equal 900.to_d, invoice.total
  end

  test "marks the swept entries as billed" do
    invoice = build

    assert_equal 2, invoice.time_entries.count
    # The entry from last month stays unbilled because it is outside the period.
    assert_equal [ time_entries(:acme_last_month) ], @acme.time_entries.billable.unbilled.to_a
  end

  test "ignores non-billable entries" do
    invoice = build

    assert_not_includes invoice.time_entries, time_entries(:acme_non_billable)
  end

  test "ignores entries outside the period" do
    invoice = build

    assert_not_includes invoice.time_entries, time_entries(:acme_last_month)
  end

  test "does not re-bill entries already on an invoice" do
    build
    second = build(period_start: @period_start - 1.month, period_end: @period_end)

    assert_equal 1, second.invoice_line_items.count
    assert_equal 4.to_d, second.hours_total
  end

  test "stamps the number, period, issue date and due date" do
    invoice = build

    assert_equal "INV-#{Date.current.strftime('%Y%m')}-001", invoice.number
    assert_equal @period_start, invoice.period_start
    assert_equal @period_end, invoice.period_end
    assert_equal Date.current + 30, invoice.due_on
    assert invoice.draft?
  end

  test "carries the notes through" do
    assert_equal "Thanks!", build(notes: "Thanks!").notes
  end

  # --- monthly ------------------------------------------------------------

  test "monthly clients get a single flat retainer line" do
    invoice = build(client: clients(:vertex))

    assert_equal 1, invoice.invoice_line_items.count
    assert invoice.invoice_line_items.first.monthly?
    assert_match(/Monthly retainer/, invoice.invoice_line_items.first.description)
    assert_equal 6000.to_d, invoice.total
  end

  test "monthly retainer hours are attached but not charged hourly" do
    invoice = build(client: clients(:vertex))

    assert_equal clients(:vertex).time_entries.billable.count, invoice.time_entries.count
    assert_equal 0, clients(:vertex).time_entries.billable.unbilled.count
    assert_equal 1, invoice.invoice_line_items.count
    assert_equal 6000.to_d, invoice.total
  end

  # --- failures -----------------------------------------------------------

  test "raises when an hourly client has nothing unbilled" do
    empty = users(:blake).clients.create!(name: "Empty Co", billing_type: "hourly", hourly_rate: 100)

    error = assert_raises(InvoiceBuilder::Error) { build(client: empty) }
    assert_match(/No unbilled billable hours/, error.message)
  end

  test "raises when the period is inverted" do
    assert_raises(InvoiceBuilder::Error) do
      build(period_start: @period_end, period_end: @period_start)
    end
  end

  test "raises when an invoice already covers the period" do
    build

    error = assert_raises(InvoiceBuilder::Error) { build }
    assert_match(/already exists/, error.message)
  end

  test "voiding an invoice releases its entries so the period can be re-invoiced" do
    first = build
    first.void!

    assert_equal 0, first.time_entries.count

    second = build
    assert_equal 2, second.invoice_line_items.count
    assert_equal 900.to_d, second.total
  end

  test "nothing is persisted when validation fails" do
    assert_no_difference -> { Invoice.count } do
      assert_raises(InvoiceBuilder::Error) do
        build(client: clients(:vertex), period_start: @period_end, period_end: @period_start)
      end
    end
  end

  # --- preview ------------------------------------------------------------

  test "preview reports hours and amount without persisting" do
    assert_no_difference -> { Invoice.count } do
      preview = InvoiceBuilder.preview(client: @acme, period_start: @period_start, period_end: @period_end)

      assert_equal 2, preview.entries.size
      assert_equal 6.to_d, preview.hours
      assert_equal 900.to_d, preview.amount
      assert preview.billable?
    end
  end

  test "preview for a monthly client quotes the retainer" do
    preview = InvoiceBuilder.preview(client: clients(:vertex), period_start: @period_start, period_end: @period_end)

    assert_equal 6000.to_d, preview.amount
    assert preview.billable?
    assert_equal clients(:vertex).time_entries.billable.unbilled.count, preview.entries.size
  end

  test "preview reports nothing billable for an empty period" do
    preview = InvoiceBuilder.preview(client: @acme, period_start: 10.years.ago.to_date, period_end: 10.years.ago.to_date + 1.day)

    assert_not preview.entries?
    assert_not preview.billable?
  end
end
