# Turns a client's unbilled time entries for a period into a persisted invoice.
#
# Hourly clients get one line item per time entry. Monthly clients get a single
# flat retainer line; any hours logged in the period are attached to the invoice
# so they are marked as billed without being charged twice.
class InvoiceBuilder
  class Error < StandardError; end

  Preview = Struct.new(:client, :period_start, :period_end, :entries, :hours, :amount, keyword_init: true) do
    def entries?
      entries.any?
    end

    def hourly?
      client.hourly?
    end

    def billable?
      hourly? ? entries? : client.monthly_rate.to_d.positive?
    end
  end

  # Non-persisting summary used to render the "new invoice" form.
  def self.preview(client:, period_start:, period_end:)
    entries = client.unbilled_entries_for(period_start, period_end).to_a
    hours = entries.sum { |entry| entry.hours.to_d }

    amount =
      if client.monthly?
        client.monthly_rate.to_d
      else
        (hours * client.hourly_rate.to_d).round(2)
      end

    Preview.new(
      client: client,
      period_start: period_start,
      period_end: period_end,
      entries: entries,
      hours: hours,
      amount: amount
    )
  end

  def initialize(client:, period_start:, period_end:, issued_on: Date.current, notes: nil)
    @client = client
    @period_start = period_start.to_date
    @period_end = period_end.to_date
    @issued_on = issued_on.presence&.to_date || Date.current
    @notes = notes.presence
  end

  def call
    validate!

    Invoice.transaction do
      invoice = client.invoices.create!(
        user: client.user,
        number: Invoice.next_number_for(client.user, issued_on),
        period_start: period_start,
        period_end: period_end,
        status: "draft",
        issued_on: issued_on,
        due_on: client.user.default_due_date(issued_on),
        notes: notes
      )

      build_line_items(invoice)
      attach_covered_entries(invoice)

      invoice.update!(
        subtotal: invoice.invoice_line_items.sum(:amount),
        total: invoice.invoice_line_items.sum(:amount)
      )

      invoice
    end
  end

  private
    attr_reader :client, :period_start, :period_end, :issued_on, :notes

    def validate!
      raise Error, "Period end must be on or after period start." if period_end < period_start

      duplicate = client.invoices.where(period_start: period_start, period_end: period_end).where.not(status: "void")
      raise Error, "An invoice already exists for that period." if duplicate.exists?

      if client.hourly? && entries.empty?
        raise Error, "No unbilled billable hours for that period."
      end
    end

    def entries
      @entries ||= client.unbilled_entries_for(period_start, period_end).to_a
    end

    def build_line_items(invoice)
      if client.monthly?
        invoice.invoice_line_items.create!(
          kind: "monthly",
          description: "Monthly retainer — #{period_end.strftime('%B %Y')}",
          quantity: 1,
          unit_rate: client.monthly_rate,
          amount: client.monthly_rate
        )
      else
        entries.each do |entry|
          invoice.invoice_line_items.create!(
            time_entry: entry,
            kind: "hourly",
            description: entry.summary,
            quantity: entry.hours,
            unit_rate: client.hourly_rate,
            amount: (entry.hours.to_d * client.hourly_rate.to_d).round(2)
          )
        end
      end
    end

    # Every entry swept into the period is flagged as billed, retainer or not.
    def attach_covered_entries(invoice)
      return if entries.empty?

      client.time_entries.where(id: entries.map(&:id)).update_all(invoice_id: invoice.id)
    end
end
