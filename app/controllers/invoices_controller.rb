class InvoicesController < ApplicationController
  before_action :set_invoice, only: %i[
    show edit update destroy mark_paid mark_sent void repeat deliver remind
  ]
  before_action :require_editable, only: %i[edit update destroy mark_paid mark_sent void deliver remind]

  def index
    @status = params[:status].presence_in(Invoice::STATUSES + [ "overdue" ])
    scope = current_user.invoices.includes(:client)

    if @status == "overdue"
      scope = scope.overdue
    elsif @status
      scope = scope.where(status: @status)
    end

    @invoices = paginate(scope.recent_first)
    @outstanding_total = current_user.invoices.open_invoices.sum(:total)
    @overdue_count = current_user.invoices.overdue.count
    @overdue_total = current_user.invoices.overdue.sum(:total)
    @paid_total = current_user.invoices.paid.sum(:total)
    @year_total = current_user.invoices.where(issued_on: Date.current.all_year).where.not(status: "void").sum(:total)
    @retainer_clients = current_user.clients.monthly.active.count
  end

  def show
    respond_to do |format|
      format.html
      format.pdf do
        send_data InvoicePdf.new(@invoice).render,
          filename: "#{@invoice.number}.pdf",
          type: "application/pdf",
          disposition: "inline"
      end
    end
  end

  def new
    load_form_state
  end

  def create
    # The "Preview" button re-renders the form inside a Turbo frame instead of
    # creating anything, so the totals can be checked before committing.
    if params[:preview].present?
      load_form_state
      return render :new
    end

    client = current_user.clients.find(params[:client_id])
    invoice = InvoiceBuilder.new(
      client: client,
      period_start: params[:period_start],
      period_end: params[:period_end],
      issued_on: parse_date(params[:issued_on]) || Date.current,
      notes: params[:notes]
    ).call

    redirect_to invoice, notice: "Invoice #{invoice.number} created."
  rescue InvoiceBuilder::Error => e
    load_form_state
    flash.now[:alert] = e.message
    render :new, status: :unprocessable_entity
  end

  def edit
  end

  def update
    if @invoice.update(invoice_params)
      redirect_to @invoice, notice: "Invoice updated."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    number = @invoice.number
    @invoice.destroy
    redirect_to invoices_path,
      notice: "Invoice #{number} was deleted; its time entries are unbilled again.",
      status: :see_other
  end

  def mark_paid
    @invoice.mark_paid!(parse_date(params[:paid_on]) || Date.current)
    redirect_to @invoice, notice: "Invoice #{@invoice.number} marked as paid."
  end

  def mark_sent
    @invoice.mark_sent!
    redirect_to @invoice, notice: "Invoice #{@invoice.number} marked as sent."
  end

  # Emails the invoice PDF to the client and records that it went out.
  def deliver
    return redirect_to @invoice, alert: no_email_message if client_email_missing?

    begin
      InvoiceMailer.invoice(@invoice).deliver_now
    rescue StandardError => e
      return redirect_to @invoice, alert: "Could not send the invoice: #{e.message}"
    end

    @invoice.mark_sent!
    redirect_to @invoice, notice: "Invoice #{@invoice.number} emailed to #{@invoice.client.email}.#{delivery_suffix}"
  end

  # Chases an invoice that is already with the client.
  def remind
    return redirect_to @invoice, alert: "Send the invoice before chasing it." unless @invoice.sent?
    return redirect_to @invoice, alert: no_email_message if client_email_missing?

    begin
      InvoiceMailer.invoice(@invoice, reminder: true).deliver_now
    rescue StandardError => e
      return redirect_to @invoice, alert: "Could not send the reminder: #{e.message}"
    end

    @invoice.update!(last_reminded_at: Time.current)
    redirect_to @invoice, notice: "Reminder for #{@invoice.number} sent to #{@invoice.client.email}.#{delivery_suffix}"
  end

  def void
    @invoice.void!
    redirect_to @invoice, notice: "Invoice #{@invoice.number} was voided; its time entries are unbilled again.", status: :see_other
  end

  # Re-bills the same client for the period after this one. Retainers are
  # identical every month, so this is the common path; hourly clients pick up
  # whatever is unbilled in the new period.
  def repeat
    period_start, period_end = @invoice.next_period

    repeated = InvoiceBuilder.new(
      client: @invoice.client,
      period_start: period_start,
      period_end: period_end,
      issued_on: Date.current,
      notes: @invoice.notes
    ).call

    redirect_to repeated, notice: "Invoice #{repeated.number} created for #{repeated.period_label}."
  rescue InvoiceBuilder::Error => e
    redirect_to @invoice, alert: "#{e.message} Nothing was created."
  end

  # Creates this month's retainer drafts for every active monthly client that
  # doesn't have one yet. Deliberately explicit rather than scheduled.
  def draft_retainers
    period_start = Date.current.beginning_of_month
    period_end = Date.current.end_of_month
    created = []
    skipped = []

    current_user.clients.monthly.active.alphabetical.each do |client|
      already_invoiced = client.invoices
        .where(period_start: period_start, period_end: period_end)
        .where.not(status: "void")
        .exists?

      if already_invoiced
        skipped << client.display_name
        next
      end

      invoice = InvoiceBuilder.new(
        client: client,
        period_start: period_start,
        period_end: period_end,
        issued_on: Date.current
      ).call

      created << invoice
    rescue InvoiceBuilder::Error
      skipped << client.display_name
    end

    redirect_to invoices_path, notice: draft_retainers_notice(created, skipped), status: :see_other
  end

  private
    def set_invoice
      @invoice = current_user.invoices.find(params[:id])
    end

    # Paid and void invoices are records of what happened; don't edit them.
    def require_editable
      return if @invoice.outstanding?

      redirect_to @invoice, alert: "A #{@invoice.status} invoice can no longer be changed."
    end

    def load_form_state
      @clients = current_user.clients.alphabetical
      @client = current_user.clients.find_by(id: params[:client_id]) || @clients.first
      @period_start = parse_date(params[:period_start]) || Date.current.beginning_of_month
      @period_end = parse_date(params[:period_end]) || Date.current.end_of_month
      @issued_on = parse_date(params[:issued_on]) || Date.current
      @notes = params[:notes]
      @preview = preview_for(@client)
      @timesheet = @client && Timesheet.new(client: @client, period_start: @period_start, period_end: @period_end)
      @invoice = Invoice.new(client: @client, period_start: @period_start, period_end: @period_end)
    end

    def preview_for(client)
      return nil if client.blank?

      InvoiceBuilder.preview(client: client, period_start: @period_start, period_end: @period_end)
    end

    # Status is deliberately not mass-assignable: voiding and marking paid must
    # run through #void! / #mark_paid! so time entries are released and paid_at
    # is recorded. Those transitions have dedicated actions on the invoice page.
    def invoice_params
      params.expect(invoice: [ :issued_on, :due_on, :period_start, :period_end, :notes ])
    end

    def draft_retainers_notice(created, skipped)
      return "No active retainer clients to draft for." if created.empty? && skipped.empty?

      parts = []
      if created.any?
        numbers = created.map(&:number).to_sentence
        parts << "Drafted #{created.size} #{'invoice'.pluralize(created.size)} (#{numbers})."
      end
      parts << "Skipped #{skipped.to_sentence} — already invoiced for this month." if skipped.any?
      parts.join(" ")
    end

    def client_email_missing?
      @invoice.client.email.blank?
    end

    def no_email_message
      "#{@invoice.client.display_name} has no billing email yet — add one on the client first."
    end

    # In development Action Mailer opens the message in a browser tab instead of
    # sending it, so the flash shouldn't claim it went out.
    def delivery_suffix
      return "" unless ActionMailer::Base.delivery_method == :letter_opener

      " (development: opened in a browser tab, not sent)"
    end
end
