class DashboardController < ApplicationController
  def show
    month_range = Date.current.beginning_of_month..Date.current.end_of_month
    entries = current_user.time_entries

    @clients = current_user.clients.alphabetical
    @active_clients = @clients.select(&:active)

    # Retainer hours are covered by the flat fee, so "unbilled" only means
    # something for hourly clients.
    hourly_clients = current_user.clients.hourly.alphabetical.to_a
    unbilled_by_client = hourly_clients.index_with { |client| client.unbilled_hours.to_d }
    @unbilled_hours = unbilled_by_client.values.sum
    @unbilled_value = hourly_clients.sum { |client| unbilled_by_client[client] * client.hourly_rate.to_d }

    @hours_this_month = entries.in_period(month_range).sum(:hours)
    @invoiced_this_month = current_user.invoices.where(issued_on: month_range).where.not(status: "void").sum(:total)
    @outstanding_total = current_user.invoices.open_invoices.sum(:total)

    @retainers = current_user.clients.monthly.active.alphabetical.map do |client|
      client.timesheet_for(Date.current)
    end

    @recent_entries = entries.includes(:client).recent_first.limit(8)
    @open_invoices = current_user.invoices.open_invoices.includes(:client).order(:due_on).limit(6)
    @open_count = current_user.invoices.open_invoices.count
    @overdue_count = current_user.invoices.overdue.count
    @overdue_total = current_user.invoices.overdue.sum(:total)

    @summary = TaxSummary.new(current_user)

    @time_entry = TimeEntry.new(worked_on: Date.current, billable: true)
    @month_range = month_range
  end
end
