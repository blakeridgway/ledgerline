require "test_helper"

class InvoicePdfTest < ActiveSupport::TestCase
  test "renders a PDF document with the invoice details" do
    invoice = invoices(:acme_old_paid)
    pdf = InvoicePdf.new(invoice).render

    assert pdf.start_with?("%PDF"), "expected a PDF header"
    assert_operator pdf.bytesize, :>, 1_000

    text = pdf_text(pdf)
    assert_includes text, invoice.number
    assert_includes text, "Acme Corp"
    assert_includes text, "$1,200.00"
  end

  test "renders a monthly retainer invoice" do
    invoice = InvoiceBuilder.new(
      client: clients(:vertex),
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month
    ).call

    pdf = InvoicePdf.new(invoice).render

    assert pdf.start_with?("%PDF")
    assert_includes pdf_text(pdf), "Monthly retainer"
    assert_includes pdf_text(pdf), invoice.number
  end

  test "renders a paid invoice with a zero balance" do
    pdf = InvoicePdf.new(invoices(:acme_old_paid)).render

    assert pdf.start_with?("%PDF")
    assert_includes pdf_text(pdf), "Balance due"
  end

  test "survives characters the built-in font cannot encode" do
    invoice = invoices(:acme_old_paid)
    invoice.notes = "Emoji 🎉, arrow →, CJK 日本語, smart “quotes”, em—dash, ellipsis…"
    invoice.client.update!(address: "1 Market St\nSan Francisco, CA 94103")

    pdf = InvoicePdf.new(invoice).render

    assert pdf.start_with?("%PDF")
    assert_includes pdf_text(pdf), "Emoji"
  end

  test "renders an invoice whose line items have no linked time entry" do
    invoice = invoices(:acme_old_draft)

    assert_equal invoice.period_end, invoice.invoice_line_items.first.service_date
    assert InvoicePdf.new(invoice).render.start_with?("%PDF")
  end
end
