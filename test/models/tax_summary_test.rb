require "test_helper"

class TaxSummaryTest < ActiveSupport::TestCase
  setup do
    @user = users(:blake)
    @year = Date.current.year
  end

  def retainer_invoice(paid: false)
    invoice = InvoiceBuilder.new(
      client: clients(:vertex),
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month,
      issued_on: Date.current
    ).call
    invoice.mark_paid! if paid
    invoice
  end

  test "totals income, expenses and net profit" do
    retainer_invoice

    summary = TaxSummary.new(@user, @year)

    assert_equal 6000.to_d, summary.income
    # 45.00 software + 320.50 travel from the fixtures.
    assert_equal 365.5.to_d, summary.expenses
    assert_equal 5634.5.to_d, summary.net_profit
  end

  test "holds back the configured share of profit" do
    retainer_invoice

    summary = TaxSummary.new(@user, @year)

    assert_equal 30.to_d, summary.set_aside_percent
    assert_equal 1690.35.to_d, summary.set_aside
  end

  test "a loss owes nothing" do
    @user.expenses.create!(
      spent_on: Date.current, vendor: "Insurance Co", category: "Insurance", amount: 5000
    )

    summary = TaxSummary.new(@user, @year)

    assert_operator summary.net_profit, :<, 0
    assert_equal 0.to_d, summary.set_aside
    assert_equal 0.to_d, summary.set_aside_for(-100)
  end

  test "separates what was invoiced from what was received" do
    retainer_invoice(paid: true)

    summary = TaxSummary.new(@user, @year)

    assert_equal 6000.to_d, summary.income
    assert_equal 6000.to_d, summary.received
  end

  test "ignores voided invoices and other people's records" do
    invoice = retainer_invoice
    invoice.void!

    summary = TaxSummary.new(@user, @year)

    assert_equal 0.to_d, summary.income
    # The rival client's 300 invoice belongs to another user.
    assert_equal 1650.to_d, TaxSummary.new(@user, 2020).income
  end

  test "received excludes an invoice that was paid and then voided" do
    invoice = retainer_invoice(paid: true)
    invoice.void!

    summary = TaxSummary.new(@user, @year)

    assert_equal 0.to_d, summary.received
  end

  test "counts only the requested year" do
    summary = TaxSummary.new(@user, 2020)

    # Both 2020 fixture invoices: a paid one and a draft one.
    assert_equal 1650.to_d, summary.income
    assert_equal 1200.to_d, summary.received
    assert_equal 0.to_d, summary.expenses
  end

  test "groups expenses by category, largest first" do
    summary = TaxSummary.new(@user, @year)
    categories = summary.expenses_by_category

    assert_equal [ "Travel", "Software and subscriptions" ], categories.keys
    assert_equal 320.5.to_d, categories["Travel"]
  end

  test "groups income by client display name" do
    retainer_invoice

    summary = TaxSummary.new(@user, @year)

    assert_equal [ [ "Finance", 6000.to_d ] ], summary.income_by_client
  end

  test "estimated instalments follow the IRS schedule" do
    summary = TaxSummary.new(@user, 2026)

    assert_equal %w[Q1 Q2 Q3 Q4], summary.quarters.map(&:label)
    assert_equal Date.new(2026, 1, 1)..Date.new(2026, 3, 31), summary.quarters[0].range
    assert_equal Date.new(2026, 4, 1)..Date.new(2026, 5, 31), summary.quarters[1].range
    assert_equal Date.new(2026, 6, 1)..Date.new(2026, 8, 31), summary.quarters[2].range
    assert_equal Date.new(2026, 9, 1)..Date.new(2026, 12, 31), summary.quarters[3].range
  end

  test "instalment due dates roll the last quarter into the next year" do
    summary = TaxSummary.new(@user, 2026)

    assert_equal Date.new(2026, 4, 15), summary.quarters[0].due_on
    assert_equal Date.new(2026, 6, 15), summary.quarters[1].due_on
    assert_equal Date.new(2026, 9, 15), summary.quarters[2].due_on
    assert_equal Date.new(2027, 1, 15), summary.quarters[3].due_on
  end

  test "quarter totals add up to the year" do
    retainer_invoice

    summary = TaxSummary.new(@user, @year)

    assert_equal summary.income, summary.quarters.sum(&:income)
    assert_equal summary.expenses, summary.quarters.sum(&:expenses)
  end

  test "points at the next instalment that has not passed" do
    year = Date.current.year + 1
    summary = TaxSummary.new(@user, year)

    # Every instalment for next year is still ahead of us, so it points at Q1.
    assert_equal "Q1", summary.next_quarter.label
    assert_equal Date.new(year, 4, 15), summary.next_quarter.due_on
  end
end
