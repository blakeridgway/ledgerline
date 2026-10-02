class ExpensesController < ApplicationController
  before_action :set_expense, only: %i[edit update destroy]
  before_action :set_clients, only: %i[new create edit update]

  def index
    @filters = filter_params
    @clients = current_user.clients.alphabetical
    @years = available_years
    @expenses = paginate(filtered_scope.includes(:client).recent_first)
    @filtered_total = filtered_scope.sum(:amount)
    @by_category = filtered_scope.group(:category)
      .order(Arel.sql("SUM(amount) DESC"))
      .sum(:amount)
  end

  def new
    @expense = current_user.expenses.new(spent_on: Date.current)
  end

  def create
    @expense = current_user.expenses.new(expense_params)

    if @expense.save
      redirect_to expenses_path(year: @expense.spent_on.year), notice: "Expense recorded."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @expense.update(expense_params)
      redirect_to expenses_path(year: @expense.spent_on.year), notice: "Expense updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    vendor = @expense.vendor
    year = @expense.spent_on.year
    @expense.destroy
    redirect_to expenses_path(year: year), notice: "#{vendor} removed.", status: :see_other
  end

  private
    def set_expense
      @expense = current_user.expenses.find(params[:id])
    end

    def set_clients
      @clients = current_user.clients.alphabetical
    end

    def expense_params
      params.expect(expense: [ :client_id, :spent_on, :vendor, :category, :amount, :notes ])
    end

    def filter_params
      {
        year: params[:year].presence&.to_i || Date.current.year,
        category: params[:category].presence_in(Expense::CATEGORIES),
        client_id: params[:client_id].presence
      }
    end

    def filtered_scope
      scope = current_user.expenses.for_year(@filters[:year])
      scope = scope.where(category: @filters[:category]) if @filters[:category]
      scope = scope.where(client_id: @filters[:client_id]) if @filters[:client_id]
      scope
    end

    # Every year that has an expense, plus the current one.
    def available_years
      first = current_user.expenses.minimum(:spent_on)
      last = [ current_user.expenses.maximum(:spent_on)&.year, Date.current.year ].compact.max
      return [ Date.current.year ] if first.nil?

      (first.year..last).to_a.reverse
    end
end
