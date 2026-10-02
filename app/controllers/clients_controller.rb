class ClientsController < ApplicationController
  before_action :set_client, only: %i[show edit update destroy timesheet]

  def index
    @status = params[:status].presence_in(%w[active archived]) || "active"
    scope = current_user.clients.alphabetical.includes(:time_entries)
    scope = scope.where(active: true) if @status == "active"
    scope = scope.where(active: false) if @status == "archived"

    @clients = scope
    @archived_count = current_user.clients.where(active: false).count
    @active_count = current_user.clients.where(active: true).count
  end

  def show
    @time_entries = paginate(@client.time_entries.recent_first)
    @invoices = @client.invoices.recent_first.limit(5)
    @unbilled_entries = @client.time_entries.billable.unbilled.chronological
    @unbilled_hours = @unbilled_entries.sum(:hours)
    @billed_to_date = @client.invoices.where.not(status: "void").sum(:total)
    @month_range = Date.current.beginning_of_month..Date.current.end_of_month
    @timesheet = @client.timesheet_for(Date.current)
    @invoice = @client.invoices.build(
      period_start: @month_range.first,
      period_end: @month_range.last
    )
  end

  # Monthly timesheet for a retainer client: HTML preview plus a PDF to submit.
  def timesheet
    month = parse_month(params[:month]) || Date.current
    @timesheet = @client.timesheet_for(month)

    respond_to do |format|
      format.html
      format.pdf do
        send_data TimesheetPdf.new(@timesheet).render,
          filename: timesheet_filename(@timesheet),
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  def new
    @client = current_user.clients.new(
      currency: current_user.default_currency,
      expected_hours_per_month: current_user.expected_hours_per_month
    )
  end

  def create
    @client = current_user.clients.new(client_params)

    if @client.save
      redirect_to @client, notice: "#{@client.display_name} was added."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @client.update(client_params)
      redirect_to @client, notice: "#{@client.display_name} was updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    name = @client.display_name
    @client.destroy
    redirect_to clients_path, notice: "#{name} was removed.", status: :see_other
  end

  private
    def set_client
      @client = current_user.clients.find(params[:id])
    end

    def client_params
      params.expect(client: [
        :name, :company, :email, :phone, :address,
        :billing_type, :hourly_rate, :monthly_rate, :expected_hours_per_month,
        :currency, :active, :notes
      ])
    end

    def parse_month(value)
      return nil unless value.to_s.match?(/\A\d{4}-\d{2}\z/)

      Date.strptime(value, "%Y-%m")
    rescue ArgumentError
      nil
    end

    def timesheet_filename(timesheet)
      slug = timesheet.client.display_name.parameterize.presence || "client"
      "#{slug}-timesheet-#{timesheet.period_start.strftime('%Y-%m')}.pdf"
    end
end
