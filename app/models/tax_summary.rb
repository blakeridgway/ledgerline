# Income, expenses and estimated tax for one calendar year.
#
# Income is recognised by invoice issue date and expenses by the date they were
# incurred — the practical proxy for a cash-basis sole trader reading their own
# books.
class TaxSummary
  # US federal estimated tax instalments are not even quarters: they cover
  # uneven month ranges, and the last one for a year is due the following
  # January.
  QUARTERS = [
    { label: "Q1", months: 1..3,  due_month: 4, due_day: 15, next_year: false },
    { label: "Q2", months: 4..5,  due_month: 6, due_day: 15, next_year: false },
    { label: "Q3", months: 6..8,  due_month: 9, due_day: 15, next_year: false },
    { label: "Q4", months: 9..12, due_month: 1, due_day: 15, next_year: true }
  ].freeze

  Quarter = Struct.new(:label, :range, :due_on, :income, :expenses, keyword_init: true) do
    def net
      income - expenses
    end

    def overdue?
      due_on < Date.current
    end
  end

  attr_reader :user, :year

  def initialize(user, year = Date.current.year)
    @user = user
    @year = year.to_i
  end

  def income
    @income ||= scoped_invoices.sum(:total)
  end

  def received
    @received ||= user.invoices.where(paid_at: year_range).where.not(status: "void").sum(:total)
  end

  def expenses
    @expenses ||= scoped_expenses.sum(:amount)
  end

  def net_profit
    income - expenses
  end

  def set_aside_percent
    user.tax_set_aside_percent.to_d
  end

  # A loss owes nothing, so the set-aside floors at zero.
  def set_aside
    set_aside_for(net_profit)
  end

  def set_aside_for(amount)
    return 0.to_d if amount.to_d <= 0

    (amount.to_d * set_aside_percent / 100).round(2)
  end

  def invoice_count
    scoped_invoices.count
  end

  def expense_count
    scoped_expenses.count
  end

  def expenses_by_category
    @expenses_by_category ||= scoped_expenses
      .group(:category)
      .order(Arel.sql("SUM(amount) DESC"))
      .sum(:amount)
  end

  def income_by_client
    @income_by_client ||= begin
      totals = scoped_invoices.group(:client_id).sum(:total)
      names = user.clients.where(id: totals.keys)
        .pluck(:id, :name, :company)
        .to_h { |id, name, company| [ id, company.presence || name ] }

      totals.map { |client_id, total| [ names[client_id] || "Unassigned", total ] }
        .sort_by { |_, total| -total }
    end
  end

  def quarters
    @quarters ||= QUARTERS.map do |definition|
      quarter_range = month_range(definition[:months])

      Quarter.new(
        label: definition[:label],
        range: quarter_range,
        due_on: due_date(definition),
        income: scoped_invoices.where(issued_on: quarter_range).sum(:total),
        expenses: scoped_expenses.where(spent_on: quarter_range).sum(:amount)
      )
    end
  end

  # The next instalment that hasn't come due yet, for the headline callout.
  def next_quarter
    quarters.find { |quarter| quarter.due_on >= Date.current } || quarters.last
  end

  def year_range
    Date.new(year, 1, 1)..Date.new(year, 12, 31)
  end

  private
    def scoped_invoices
      @scoped_invoices ||= user.invoices.where(issued_on: year_range).where.not(status: "void")
    end

    def scoped_expenses
      @scoped_expenses ||= user.expenses.for_year(year)
    end

    def month_range(months)
      Date.new(year, months.first, 1)..Date.new(year, months.last, -1)
    end

    def due_date(definition)
      Date.new(definition[:next_year] ? year + 1 : year, definition[:due_month], definition[:due_day])
    end
end
