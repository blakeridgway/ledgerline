require "test_helper"

class InvoiceLineItemTest < ActiveSupport::TestCase
  setup do
    @line = invoice_line_items(:acme_old_hourly_line)
  end

  test "is valid with the fixture data" do
    assert @line.valid?
  end

  test "requires a description" do
    @line.description = nil

    assert_not @line.valid?
    assert_includes @line.errors[:description], "can't be blank"
  end

  test "rejects an unknown kind" do
    @line.kind = "weekly"

    assert_not @line.valid?
  end

  test "service_date falls back to the invoice period end" do
    assert_equal invoices(:acme_old_paid).period_end, @line.service_date
  end

  test "service_date uses the linked time entry date" do
    entry = time_entries(:acme_unbilled_a)
    @line.time_entry = entry

    assert_equal entry.worked_on, @line.service_date
  end
end
