# Renders an Invoice as a printable PDF using Prawn.
class InvoicePdf
  include PdfHelpers

  SIDE_COLUMN = 200

  def initialize(invoice)
    @invoice = invoice
    @client = invoice.client
    @user = invoice.user
  end

  def render
    document = Prawn::Document.new(
      page_size: "LETTER",
      margin: MARGIN,
      info: {
        Title: "Invoice #{safe(invoice.number)}",
        Author: safe(user.billing_name),
        Creator: "time_logix"
      }
    )

    build_letterhead(document)
    build_parties(document)
    build_line_items(document)
    build_totals(document)
    build_notes(document)
    build_footer(document)

    document.render
  end

  private
    attr_reader :invoice, :client, :user

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

      right = pdf.make_table([ [ safe("INVOICE") ] ]) do
        cells.borders = []
        cells.padding = [ 0, 0 ]
        cells.size = 26
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
      bill_to = [ [ safe("BILL TO") ] ] + [ [ safe(client.display_name) ] ] +
        client_details.map { |line| [ safe(line) ] }

      left = pdf.make_table(bill_to, column_widths: [ left_width ]) do
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

      value_width = 110
      right = pdf.make_table(invoice_meta_rows, column_widths: [ SIDE_COLUMN - value_width, value_width ]) do
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

    def build_line_items(pdf)
      rows = [ [ "Date", "Description", "Qty / Hrs", "Rate", "Amount" ] ]

      invoice.invoice_line_items.each do |item|
        rows << [
          safe(pdf_date(item.service_date)),
          safe(item.description),
          safe(item.hourly? ? hours_label(item.quantity) : "1"),
          safe(money(item.unit_rate, currency)),
          safe(money(item.amount, currency))
        ]
      end

      rows << [ "", safe("No billable items for this period."), "", "", "" ] if rows.size == 1

      # Description takes whatever space the fixed columns leave over.
      description_width = pdf.bounds.width - (78 + 60 + 70 + 80)

      pdf.move_down 26
      pdf.table(
        rows,
        column_widths: [ 78, description_width, 60, 70, 80 ],
        header: true
      ) do
        cells.size = 9
        cells.padding = [ 7, 6 ]
        cells.borders = [ :bottom ]
        cells.border_color = HAIRLINE
        cells.text_color = INK

        row(0).font_style = :bold
        row(0).size = 8
        row(0).text_color = MUTED
        row(0).border_color = "C6CFD6"

        column(2).align = :right
        column(3).align = :right
        column(4).align = :right
        column(4).font_style = :bold
      end
    end

    def build_totals(pdf)
      rows = [
        [ safe("Subtotal"), safe(money(invoice.subtotal, currency)) ],
        [ safe("Total"), safe(money(invoice.total, currency)) ]
      ]

      if invoice.paid?
        rows << [ safe("Paid #{pdf_date(invoice.paid_at&.to_date)}"), safe("(#{money(invoice.total, currency)})") ]
        rows << [ safe("Balance due"), safe(money(0, currency)) ]
      end

      pdf.move_down 16
      pdf.table(rows, column_widths: [ 140, 100 ], position: :right) do
        cells.borders = []
        cells.padding = [ 4, 10 ]
        cells.size = 10
        cells.text_color = MUTED
        column(1).align = :right
        column(1).width = 100
        column(1).text_color = INK
        row(1).font_style = :bold
        row(1).size = 12
        row(-1).font_style = :bold
        row(-1).text_color = ACCENT
      end
    end

    def build_notes(pdf)
      blocks = []
      blocks << [ "Notes", invoice.notes ] if invoice.notes.present?
      blocks << [ "Payment instructions", user.payment_instructions ] if user.payment_instructions.present?
      return if blocks.empty?

      pdf.move_down 34
      blocks.each do |title, body|
        pdf.text safe(title), size: 8, style: :bold, color: MUTED
        pdf.move_down 2
        pdf.text safe(body), size: 9, color: INK
        pdf.move_down 10
      end
    end

    def build_footer(pdf)
      pdf.number_pages(
        "#{safe(user.billing_name)} - Invoice #{safe(invoice.number)} - Page <page> of <total>",
        at: [ 0, -MARGIN + 20 ],
        align: :center,
        size: 8,
        color: MUTED
      )
    end

    def currency
      client.currency_symbol
    end

    def invoice_meta_rows
      [
        [ safe("Invoice no."), safe(invoice.number) ],
        [ safe("Issued"), safe(pdf_date(invoice.issued_on)) ],
        [ safe("Due"), safe(pdf_date(invoice.due_on)) ],
        [ safe("Period"), safe("#{pdf_date(invoice.period_start)} - #{pdf_date(invoice.period_end)}") ]
      ]
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
