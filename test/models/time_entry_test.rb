require "test_helper"

class TimeEntryTest < ActiveSupport::TestCase
  setup do
    @hourly_entry = time_entries(:acme_unbilled_a)
    @monthly_entry = time_entries(:vertex_retainer_hours)
    @non_billable = time_entries(:acme_non_billable)
  end

  test "is valid with the fixture data" do
    assert @hourly_entry.valid?
  end

  test "requires a worked_on date" do
    entry = clients(:acme).time_entries.new(hours: 1, worked_on: nil)

    assert_not entry.valid?
    assert_includes entry.errors[:worked_on], "can't be blank"
  end

  test "requires positive hours" do
    entry = clients(:acme).time_entries.new(worked_on: Date.current, hours: 0)

    assert_not entry.valid?
    assert_includes entry.errors[:hours], "must be greater than 0"
  end

  test "amount bills hourly entries at the client rate" do
    assert_equal 375.to_d, @hourly_entry.amount
  end

  test "amount is zero for monthly retainers" do
    assert_equal 0.to_d, @monthly_entry.amount
  end

  test "amount is zero when the entry is not billable" do
    assert_equal 0.to_d, @non_billable.amount
  end

  test "unbilled scope excludes entries already on an invoice" do
    billed = time_entries(:acme_unbilled_a)
    billed.update!(invoice: invoices(:acme_old_paid))

    assert_not_includes TimeEntry.unbilled, billed
    assert_includes TimeEntry.billed, billed
  end

  test "in_period filters on worked_on" do
    this_month = TimeEntry.in_period(Date.current.all_month)

    assert_includes this_month, @hourly_entry
    assert_not_includes this_month, time_entries(:acme_last_month)
  end

  test "summary falls back when the description is blank" do
    @hourly_entry.description = nil

    assert_equal "Time entry", @hourly_entry.summary
  end

  test "delegates display_name to the client" do
    assert_equal "Acme Corp", @hourly_entry.display_name
  end

  test "break minutes default to zero" do
    entry = clients(:acme).time_entries.new(worked_on: Date.current, hours: 1)

    assert entry.valid?
    assert_equal 0, entry.break_minutes
  end

  test "rejects negative break minutes" do
    entry = clients(:acme).time_entries.new(worked_on: Date.current, hours: 1, break_minutes: -5)

    assert_not entry.valid?
    assert_includes entry.errors[:break_minutes], "must be greater than or equal to 0"
  end

  test "reports break hours" do
    entry = clients(:acme).time_entries.new(worked_on: Date.current, hours: 1, break_minutes: 90)

    assert_equal 1.5.to_d, entry.break_hours
  end
end
