require "test_helper"

class TimesheetPdfTest < ActiveSupport::TestCase
  test "renders a timesheet with the client, hours and commitment" do
    sheet = clients(:vertex).timesheet_for(Date.current)
    pdf = TimesheetPdf.new(sheet).render

    assert pdf.start_with?("%PDF"), "expected a PDF header"
    assert_operator pdf.bytesize, :>, 1_000

    text = pdf_text(pdf)
    assert_includes text, "TIMESHEET"
    assert_includes text, "Finance"
    assert_includes text, "160"
    assert_includes text, "11.5 of 160 hrs"
  end

  test "lists each day's hours" do
    pdf = TimesheetPdf.new(clients(:vertex).timesheet_for(Date.current)).render
    text = pdf_text(pdf)

    assert_includes text, "Sprint planning"
    assert_includes text, "Code review"
    assert_includes text, "7.5"
  end

  test "notes excluded non-billable hours" do
    pdf = TimesheetPdf.new(clients(:vertex).timesheet_for(Date.current)).render

    assert_includes pdf_text(pdf), "non-billable hour"
  end

  test "renders a retainer with no commitment" do
    pdf = TimesheetPdf.new(clients(:halcyon).timesheet_for(Date.current)).render

    assert pdf.start_with?("%PDF")
    assert_includes pdf_text(pdf), "Logged hours"
  end

  test "an hourly client's timesheet is a plain hours log" do
    pdf = TimesheetPdf.new(clients(:acme).timesheet_for(Date.current)).render
    text = pdf_text(pdf)

    assert pdf.start_with?("%PDF")
    assert_includes text, "Logged hours"
    assert_includes text, "Discovery workshop"
    assert_not_includes text, "Retainer"
  end

  test "renders an empty month" do
    sheet = clients(:vertex).timesheet_for(Date.current - 6.months)
    pdf = TimesheetPdf.new(sheet).render

    assert pdf.start_with?("%PDF")
    assert_includes pdf_text(pdf), "No billable hours logged in this period"
  end

  test "links the invoice covering the period when there is one" do
    client = clients(:vertex)
    invoice = InvoiceBuilder.new(
      client: client,
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month
    ).call

    pdf = TimesheetPdf.new(client.timesheet_for(Date.current)).render

    assert_includes pdf_text(pdf), invoice.number
  end

  test "survives characters the built-in font cannot encode" do
    sheet = clients(:vertex).timesheet_for(Date.current)
    sheet.entries.first.update!(description: "Emoji 🎉, arrow →, smart “quotes”")

    pdf = TimesheetPdf.new(sheet).render

    assert pdf.start_with?("%PDF")
    assert_includes pdf_text(pdf), "Emoji"
  end
end
