class ReportsController < ApplicationController
  def show
    @year = report_year
    @summary = TaxSummary.new(current_user, @year)
    @years = available_years
  end

  private
    def report_year
      return Date.current.year if params[:year].blank?

      year = params[:year].to_i
      year.between?(1970, 2100) ? year : Date.current.year
    end

    def available_years
      invoice_years = current_user.invoices.where.not(issued_on: nil).pluck(:issued_on).map(&:year)
      expense_years = current_user.expenses.pluck(:spent_on).map(&:year)
      years = (invoice_years + expense_years + [ Date.current.year ]).uniq.sort.reverse
      years.presence || [ Date.current.year ]
    end
end
