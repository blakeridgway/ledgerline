require "test_helper"

class TimesheetTest < ActiveSupport::TestCase
  setup do
    @vertex = clients(:vertex)
    @month_start = Date.current.beginning_of_month
    @sheet = @vertex.timesheet_for(Date.current)
  end

  test "counts only billable hours in the period" do
    # 4 on the 1st, 4 + 3.5 on the 2nd; the non-billable hour is excluded.
    assert_equal 11.5.to_d, @sheet.total_hours
  end

  test "rolls entries up per day" do
    assert_equal 2, @sheet.days.size
    assert_equal [ 4.to_d, 7.5.to_d ], @sheet.days.map(&:hours)
  end

  test "joins the descriptions of a day's entries" do
    assert_equal [ "Code review", "Sprint planning" ], @sheet.days.last.descriptions.sort
    assert_match(/Code review/, @sheet.days.last.description)
  end

  test "reports days logged" do
    assert_equal 2, @sheet.days_logged
  end

  test "excludes non-billable hours but reports them separately" do
    assert_equal 1.to_d, @sheet.non_billable_hours
    assert_not_includes @sheet.entries, time_entries(:vertex_non_billable)
  end

  test "knows the client has a commitment" do
    assert @sheet.target?
    assert_equal 160.to_d, @sheet.expected_hours
  end

  test "reports what is left against the commitment" do
    assert_equal 148.5.to_d, @sheet.remaining_hours
    assert_equal 0.to_d, @sheet.over_hours
    assert_not @sheet.complete?
  end

  test "reports overage without going negative" do
    @vertex.update!(expected_hours_per_month: 8)
    sheet = @vertex.timesheet_for(Date.current)

    assert_equal 0.to_d, sheet.remaining_hours
    assert_equal 3.5.to_d, sheet.over_hours
    assert sheet.complete?
    assert_equal 144, sheet.progress_percent
  end

  test "progress percent tracks the commitment" do
    assert_equal 7, @sheet.progress_percent
  end

  test "a retainer without a commitment has no target" do
    sheet = clients(:halcyon).timesheet_for(Date.current)

    assert_not sheet.target?
    assert_nil sheet.remaining_hours
    assert_nil sheet.progress_percent
    assert_equal 0.to_d, sheet.total_hours
  end

  test "an hourly client never has a target" do
    sheet = clients(:acme).timesheet_for(Date.current)

    assert_not sheet.target?
    assert_nil sheet.progress_percent
  end

  test "only counts hours inside the requested month" do
    previous = @vertex.timesheet_for(Date.current - 1.month)

    assert_equal 0.to_d, previous.total_hours
    assert_empty previous.days
  end

  test "period covers the calendar month" do
    assert_equal @month_start, @sheet.period_start
    assert_equal Date.current.end_of_month, @sheet.period_end
    assert_equal Date.current.strftime("%B %Y"), @sheet.month_label
  end

  test "for_month builds the whole calendar month" do
    sheet = Timesheet.for_month(@vertex, Date.new(2026, 2, 14))

    assert_equal Date.new(2026, 2, 1), sheet.period_start
    assert_equal Date.new(2026, 2, 28), sheet.period_end
  end
end
