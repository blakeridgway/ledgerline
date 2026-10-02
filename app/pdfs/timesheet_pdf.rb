# Renders a monthly Timesheet as a printable PDF, for retainer clients whose
# hours have to be evidenced even though the fee is flat.
class TimesheetPdf
  include PdfHelpers

  SIDE_COLUMN = 200
  COLUMN_WIDTHS = [ 78, 42, 326, 70 ].freeze

  def initialize(timesheet)
    @timesheet = timesheet
    @client = timesheet.client
    @user = client.user
  end

  def render
    document = Prawn::Document.new(
      page_size: "LETTER",
      margin: MARGIN,
      info: {
        Title: "Timesheet #{safe(client.display_name)} #{safe(timesheet.month_label)}",
        Author: safe(user.billing_name),
        Creator: "Ledger Line"
      }
    )

    build_letterhead(document)
    build_parties(document)
    build_summary(document)
    build_days(document)
    build_footnotes(document)
    build_signature(document)
    build_footer(document)

    document.render
  end

  private
    attr_reader :timesheet, :client, :user

    def build_letterhead(pdf)
      left = pdf.make_table([ [ safe(user.billing_name) ] ] + from_details.map { |line| [ safe(line) ] }) do
        cells.borders = []
        cells.padding = [ 0, 0 ]
        cells.size = 9
        cells.text_color = MUTED
        row(0).size = 18
        row(0).font_style = :bold
        row(0).text_color = INK
        row(0).padding = [ 0, 0, 6, 0 ]
      end

      right = pdf.make_table([ [ safe("TIMESHEET") ] ]) do
        cells.borders = []
        cells.padding = [ 0, 0 ]
        cells.size = 24
        cells.font_style = :bold
        cells.text_color = ACCENT
        cells.align = :right
      end

      pdf.table([ [ left, right ] ], column_widths: [ pdf.bounds.width - SIDE_COLUMN, SIDE_COLUMN ]) do
        cells.borders = []
        cells.padding = [ 0, 0 ]
      end

      pdf.move_down 14
      pdf.stroke_color RULE
      pdf.stroke_horizontal_rule
    end

    def build_parties(pdf)
      left_width = pdf.bounds.width - SIDE_COLUMN
      left_rows = [ [ safe("TIMESHEET FOR") ], [ safe(client.display_name) ] ] +
        client_details.map { |line| [ safe(line) ] }

      left = pdf.make_table(left_rows, column_widths: [ left_width ]) do
        cells.borders = []
        cells.padding = [ 0, 0 ]
        cells.size = 9
        cells.text_color = MUTED
        row(0).size = 8
        row(0).font_style = :bold
        row(1).size = 12
        row(1).font_style = :bold
        row(1).text_color = INK
        row(1).padding = [ 2, 0, 4, 0 ]
      end

      value_width = 120
      right = pdf.make_table(meta_rows, column_widths: [ SIDE_COLUMN - value_width, value_width ]) do
        cells.borders = []
        cells.padding = [ 2, 0 ]
        cells.size = 9
        cells.text_color = MUTED
        column(1).align = :right
        column(1).font_style = :bold
        column(1).text_color = INK
      end

      pdf.move_down 22
      pdf.table([ [ left, right ] ], column_widths: [ left_width, SIDE_COLUMN ]) do
        cells.borders = []
        cells.padding = [ 0, 0 ]
        cells.vertical_align = :top
      end
    end

    # A wide strip of the headline numbers: expected / logged / remaining.
    def build_summary(pdf)
      summary = summary_cells
      return if summary.empty?

      width = pdf.bounds.width / summary.size.to_f

      pdf.move_down 24
      pdf.table(
        [
          summary.map { |label, _| safe(label) },
          summary.map { |_, value| safe(value) }
        ],
        column_widths: Array.new(summary.size) { width }
      ) do
        cells.borders = []
        cells.padding = [ 0, 8 ]
        row(0).size = 8
        row(0).font_style = :bold
        row(0).text_color = MUTED
        row(0).padding = [ 0, 8, 2, 8 ]
        row(1).size = 15
        row(1).font_style = :bold
        row(1).text_color = INK
        row(1).padding = [ 0, 8, 8, 8 ]
      end

      pdf.move_down 10
      pdf.stroke_color RULE
      pdf.stroke_horizontal_rule
    end

    def build_days(pdf)
      rows = [ [ "Date", "Day", "Work", "Hours" ] ]

      timesheet.days.each do |day|
        rows << [
          safe(pdf_date(day.date)),
          safe(day.date.strftime("%a")),
          safe(day.description),
          safe(hours_label(day.hours))
        ]
      end

      if timesheet.days.empty?
        rows << [ "", "", safe("No billable hours logged in this period."), "" ]
      end

      pdf.move_down 18
      pdf.table(rows, column_widths: COLUMN_WIDTHS, header: true) do
        cells.size = 9
        cells.padding = [ 7, 6 ]
        cells.borders = [ :bottom ]
        cells.border_color = HAIRLINE
        cells.text_color = INK

        row(0).font_style = :bold
        row(0).size = 8
        row(0).text_color = MUTED
        row(0).border_color = "C6CFD6"

        column(1).text_color = MUTED
        column(3).align = :right
        column(3).font_style = :bold
      end

      build_total_row(pdf)
    end

    def build_total_row(pdf)
      pdf.move_down 6
      pdf.table([ [ safe(total_label), safe(hours_label(timesheet.total_hours)) ] ],
        column_widths: [ pdf.bounds.width - 70, 70 ], position: :right) do
        cells.borders = [ :top ]
        cells.border_color = "C6CFD6"
        cells.padding = [ 8, 6 ]
        cells.size = 11
        cells.font_style = :bold
        cells.text_color = INK
        column(1).align = :right
        column(0).text_color = MUTED
      end
    end

    def build_footnotes(pdf)
      notes = []
      notes << "Hours shown are billable entries logged for this client during the period."
      if timesheet.non_billable_hours.positive?
        hours = timesheet.non_billable_hours
        notes << "#{hours_label(hours)} non-billable #{'hour'.pluralize(hours.to_i)} logged in the " \
                 "same period #{hours == 1 ? 'is' : 'are'} excluded."
      end

      pdf.move_down 16
      notes.each do |note|
        pdf.text safe(note), size: 8, color: MUTED
      end
    end

    def build_signature(pdf)
      pdf.move_down 30
      line_width = (pdf.bounds.width - 40) / 2

      pdf.table(
        [ [ safe("Approved by"), safe("Date") ] ],
        column_widths: [ line_width, line_width ]
      ) do
        cells.borders = [ :bottom ]
        cells.border_color = "A9B4BF"
        cells.padding = [ 22, 0, 4, 0 ]
        cells.size = 8
        cells.text_color = MUTED
      end
    end

    def build_footer(pdf)
      pdf.number_pages(
        "#{safe(user.billing_name)} - Timesheet #{safe(client.display_name)} " \
        "#{safe(timesheet.month_label)} - Page <page> of <total>",
        at: [ 0, -MARGIN + 20 ],
        align: :center,
        size: 8,
        color: MUTED
      )
    end

    def meta_rows
      rows = [
        [ safe("Period"), safe("#{pdf_date(timesheet.period_start)} - #{pdf_date(timesheet.period_end)}") ],
        [ safe("Prepared"), safe(pdf_date(Date.current)) ],
        [ safe("Days logged"), safe(timesheet.days_logged.to_s) ]
      ]

      if client.monthly?
        rows << [ safe("Retainer"), safe("#{money(client.monthly_rate, currency)}/mo") ]

        if client.effective_hourly_rate
          rows << [ safe("Effective rate"), safe("#{money(client.effective_hourly_rate, currency)}/hr") ]
        end
      end

      if (invoice = linked_invoice)
        rows << [ safe("Invoice"), safe(invoice.number) ]
      end

      rows
    end

    def summary_cells
      if timesheet.target?
        over = timesheet.over_hours.positive?
        [
          [ "Expected hours", hours_label(timesheet.expected_hours) ],
          [ "Logged", hours_label(timesheet.total_hours) ],
          [ over ? "Over" : "Remaining", hours_label(over ? timesheet.over_hours : timesheet.remaining_hours) ],
          [ "Retainer", money(client.monthly_rate, currency) ]
        ]
      else
        # Hourly clients get a plain hours log with no retainer figures.
        cells = [
          [ "Logged hours", hours_label(timesheet.total_hours) ],
          [ "Days logged", timesheet.days_logged.to_s ]
        ]
        cells << [ "Retainer", money(client.monthly_rate, currency) ] if client.monthly?
        cells
      end
    end

    def total_label
      if timesheet.target?
        "#{hours_label(timesheet.total_hours)} of #{hours_label(timesheet.expected_hours)} hrs"
      else
        "Total hours"
      end
    end

    def linked_invoice
      @linked_invoice ||= client.invoices
        .where.not(status: "void")
        .where("period_start <= ? AND period_end >= ?", timesheet.period_end, timesheet.period_start)
        .recent_first
        .first
    end

    def currency
      client.currency_symbol
    end

    def from_details
      [ user.address, user.phone, user.email_address, tax_id_line ].compact
        .flat_map { |chunk| chunk.to_s.split("\n") }
        .map(&:strip)
        .reject(&:blank?)
    end

    def client_details
      [ client.name, client.address, client.email, client.phone ]
        .compact
        .flat_map { |chunk| chunk.to_s.split("\n") }
        .map(&:strip)
        .reject(&:blank?)
        .reject { |line| line == client.display_name }
    end

    def tax_id_line
      "Tax ID: #{user.tax_id}" if user.tax_id.present?
    end
end
