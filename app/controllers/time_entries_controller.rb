class TimeEntriesController < ApplicationController
  before_action :set_time_entry, only: %i[edit update destroy]
  before_action :prevent_billed_changes, only: %i[edit update destroy]

  def index
    @clients = current_user.clients.alphabetical
    @filters = filter_params
    @time_entries = paginate(filtered_scope.includes(:client).recent_first)
    @filtered_hours = filtered_scope.sum(:hours)
    @filtered_value = filtered_value
    @time_entry = TimeEntry.new(worked_on: Date.current, billable: true, client_id: @filters[:client_id])
  end

  # A week-at-a-glance grid: one row per day, so a full-time retainer month is
  # five submissions instead of twenty.
  def batch
    load_batch_state
  end

  def save_batch
    client = current_user.clients.find(params[:client_id])
    rows = batch_rows
    created = []
    failures = []

    rows.each do |row|
      hours = row[:hours].to_s.strip
      next if hours.blank?

      # An explicit zero means "nothing that day"; anything else is handed to
      # the model so a typo surfaces as a validation error instead of silence.
      numeric = Float(hours, exception: false)
      next if numeric&.zero?

      entry = client.time_entries.new(
        worked_on: row[:worked_on],
        hours: hours,
        description: row[:description],
        billable: batch_billable?
      )

      if entry.save
        created << entry
      else
        # entry.worked_on is cast even when the record is invalid; fall back to
        # the raw value so the message always names a day.
        label = helpers.date_label(entry.worked_on).presence || row[:worked_on].to_s
        failures << "#{label}: #{entry.errors.full_messages.to_sentence}"
      end
    end

    redirect_to batch_time_entries_path(client_id: client.id, week_start: parsed_week_start),
      notice: created.any? ? batch_notice(created) : nil,
      alert: batch_alert(created, failures)
  end

  def create
    client = current_user.clients.find(time_entry_params[:client_id])
    @time_entry = client.time_entries.new(time_entry_params.except(:client_id))

    if @time_entry.save
      redirect_after_write(time_entries_path, "Logged #{helpers.hours_label(@time_entry.hours)} for #{@time_entry.display_name}.")
    else
      @clients = current_user.clients.alphabetical
      @filters = filter_params
      @time_entries = paginate(filtered_scope.includes(:client).recent_first)
      @filtered_hours = filtered_scope.sum(:hours)
      @filtered_value = filtered_value
      render :index, status: :unprocessable_entity
    end
  end

  def edit
    @clients = current_user.clients.alphabetical
  end

  def update
    if @time_entry.update(time_entry_params.except(:client_id))
      redirect_after_write(time_entries_path, "Time entry updated.")
    else
      @clients = current_user.clients.alphabetical
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @time_entry.destroy
    redirect_to time_entries_path, notice: "Time entry deleted.", status: :see_other
  end

  private
    def set_time_entry
      @time_entry = current_user.time_entries.find(params[:id])
    end

    # A billed entry is part of an invoice that was already issued; changing or
    # deleting it would desync that invoice (and a delete trips the
    # invoice_line_items foreign key). Void the invoice to release its hours.
    def prevent_billed_changes
      return if @time_entry.invoice_id.nil?

      redirect_to time_entries_path,
        alert: "That entry is on invoice #{@time_entry.invoice.number}. Void or delete the invoice to release it first."
    end

    def time_entry_params
      params.expect(time_entry: [ :client_id, :worked_on, :hours, :description, :billable ])
    end

    def filter_params
      {
        client_id: params[:client_id].presence,
        from: parse_date(params[:from]),
        to: parse_date(params[:to]),
        status: params[:status].presence_in(%w[all billed unbilled])
      }
    end

    def filtered_scope
      scope = current_user.time_entries
      scope = scope.where(client_id: @filters[:client_id]) if @filters[:client_id]
      scope = scope.where(worked_on: @filters[:from]..) if @filters[:from]
      scope = scope.where(worked_on: ..@filters[:to]) if @filters[:to]
      scope = scope.billed if @filters[:status] == "billed"
      scope = scope.unbilled if @filters[:status] == "unbilled"
      scope
    end

    def filtered_value
      filtered_scope.billable.includes(:client).sum { |entry| entry.amount }
    end

    # --- Week grid -----------------------------------------------------------

    def load_batch_state
      @clients = current_user.clients.alphabetical
      @client = current_user.clients.find_by(id: params[:client_id]) || @clients.first
      @week_start = parsed_week_start
      @days = (0..6).map { |offset| @week_start + offset.days }
      @logged_by_day = @client ? @client.time_entries.in_period(@week_start..@days.last).group(:worked_on).sum(:hours) : {}
      @timesheet = @client&.monthly? ? @client.timesheet_for(@week_start) : nil
    end

    def parsed_week_start
      (parse_date(params[:week_start]) || Date.current).beginning_of_week(:monday)
    end

    # Rows arrive as days[0][worked_on], days[0][hours], ... — blank rows are
    # skipped so an empty day logs nothing rather than a zero-hour entry.
    def batch_rows
      days = params.permit(days: [ :worked_on, :hours, :description ])[:days] || {}

      days.each_value.map do |row|
        {
          worked_on: row[:worked_on],
          hours: row[:hours].to_s,
          description: row[:description].to_s.strip
        }
      end
    end

    def batch_billable?
      params[:billable].to_s != "0"
    end

    def batch_notice(created)
      hours = created.sum { |entry| entry.hours.to_d }
      "Logged #{created.size} #{'entry'.pluralize(created.size)} (#{helpers.hours_label(hours)} hrs)."
    end

    def batch_alert(created, failures)
      return failures.first(3).to_sentence if failures.any?
      return "Enter hours for at least one day." if created.empty?

      nil
    end
end
