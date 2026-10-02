require "test_helper"

class InvoicesControllerTest < ActionDispatch::IntegrationTest
  setup do
    sign_in_as users(:blake)
    @client = clients(:acme)
    @period_start = Date.current.beginning_of_month
    @period_end = Date.current.end_of_month
  end

  test "index lists invoices" do
    get invoices_path

    assert_response :success
    assert_select "td", /INV-202001-001/
    assert_no_match "SAM-202001-001", response.body
  end

  test "index filters by status" do
    get invoices_path(status: "draft")

    assert_response :success
    assert_select "td", /INV-202001-002/
    assert_no_match "INV-202001-001", response.body
  end

  test "new renders the form and preview" do
    get new_invoice_path(client_id: @client.id)

    assert_response :success
    assert_select "turbo-frame#invoice_preview"
    assert_select "td", /Discovery workshop/
  end

  test "the preview refreshes through a Turbo frame, not a full page submit" do
    get new_invoice_path(client_id: @client.id)

    assert_response :success
    # Turbo reads data-turbo-frame from the submitter. Without it the POST is
    # treated as a full page submission, which Turbo only accepts when the
    # response redirects -- so the preview would silently never update.
    assert_select "button[name=preview][data-turbo-frame=?]", "invoice_preview"
    assert_select "form[data-controller=?]", "invoice-preview"
  end

  test "changing the client re-renders the preview without creating an invoice" do
    assert_no_difference -> { Invoice.count } do
      post invoices_path, params: {
        client_id: clients(:vertex).id,
        period_start: @period_start,
        period_end: @period_end,
        preview: "1"
      }
    end

    assert_response :success
    assert_select "turbo-frame#invoice_preview" do
      assert_select "strong", "Finance"
      assert_select "td", /Monthly retainer/
    end
  end

  test "create builds an invoice from unbilled hours" do
    assert_difference -> { Invoice.count }, 1 do
      post invoices_path, params: {
        client_id: @client.id,
        period_start: @period_start,
        period_end: @period_end,
        issued_on: Date.current
      }
    end

    invoice = Invoice.order(:id).last
    assert_redirected_to invoice_path(invoice)
    assert_equal 2, invoice.invoice_line_items.count
    assert_equal 900.to_d, invoice.total
  end

  test "create previews instead of persisting when preview is present" do
    assert_no_difference -> { Invoice.count } do
      post invoices_path, params: {
        client_id: @client.id,
        period_start: @period_start,
        period_end: @period_end,
        preview: "1"
      }
    end

    assert_response :success
    assert_select "turbo-frame#invoice_preview"
    assert_select "td", /Data model review/
  end

  test "create reports an empty period without crashing" do
    assert_no_difference -> { Invoice.count } do
      post invoices_path, params: {
        client_id: @client.id,
        period_start: 10.years.ago.to_date,
        period_end: 10.years.ago.to_date + 1.day
      }
    end

    assert_response :unprocessable_entity
    assert_match(/No unbilled billable hours/, response.body)
  end

  test "show renders the invoice" do
    get invoice_path(invoices(:acme_old_draft))

    assert_response :success
    assert_select "h1", /INV-202001-002/
  end

  test "show serves a PDF" do
    get invoice_path(invoices(:acme_old_paid), format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "update edits an outstanding invoice" do
    invoice = invoices(:acme_old_draft)

    patch invoice_path(invoice), params: { invoice: { notes: "Updated note" } }

    assert_redirected_to invoice_path(invoice)
    assert_equal "Updated note", invoice.reload.notes
  end

  test "locked invoices cannot be edited" do
    get edit_invoice_path(invoices(:acme_old_paid))

    assert_redirected_to invoice_path(invoices(:acme_old_paid))
  end

  test "update cannot change status and bypass the void transition" do
    invoice = invoices(:acme_old_draft)

    patch invoice_path(invoice), params: { invoice: { status: "void", notes: "Attempted void" } }

    assert_redirected_to invoice_path(invoice)
    invoice.reload
    assert invoice.draft?
    assert_equal "Attempted void", invoice.notes
  end

  test "issued_on cannot be blanked" do
    invoice = invoices(:acme_old_draft)

    patch invoice_path(invoice), params: { invoice: { issued_on: "" } }

    assert_response :unprocessable_entity
    assert invoice.reload.issued_on.present?
  end

  test "create with an unparseable period reports an error instead of crashing" do
    assert_no_difference -> { Invoice.count } do
      post invoices_path, params: {
        client_id: @client.id,
        period_start: "not-a-date",
        period_end: "also-not-a-date"
      }
    end

    assert_response :unprocessable_entity
    assert_match(/valid period/, response.body)
  end

  test "voided invoices are excluded from the year total" do
    invoice = retainer_invoice
    invoice.void!

    get invoices_path

    assert_response :success
    assert_match(%r{Invoiced this year</div>\s*<div class="stat__value">\$0\.00}, response.body)
  end

  test "mark_sent moves a draft to sent" do
    post mark_sent_invoice_path(invoices(:acme_old_draft))

    assert invoices(:acme_old_draft).reload.sent?
  end

  test "mark_paid records payment" do
    post mark_paid_invoice_path(invoices(:acme_old_draft))

    assert invoices(:acme_old_draft).reload.paid?
  end

  test "void closes an invoice" do
    post void_invoice_path(invoices(:acme_old_draft))

    assert invoices(:acme_old_draft).reload.void?
  end

  test "destroy releases the time entries" do
    invoice = InvoiceBuilder.new(client: @client, period_start: @period_start, period_end: @period_end).call

    assert_difference -> { Invoice.count }, -1 do
      delete invoice_path(invoice)
    end

    assert_equal 0, @client.time_entries.billed.count
    assert_redirected_to invoices_path
  end

  test "void releases the time entries" do
    invoice = InvoiceBuilder.new(client: @client, period_start: @period_start, period_end: @period_end).call
    post void_invoice_path(invoice)

    assert invoice.reload.void?
    assert_equal 0, invoice.time_entries.count
    # The two swept entries join the one that was never billed.
    assert_equal 3, @client.time_entries.billable.unbilled.count
  end

  test "cannot reach another user's invoice" do
    get invoice_path(invoices(:rival_old_draft))
    assert_response :not_found

    get invoice_path(invoices(:rival_old_draft), format: :pdf)
    assert_response :not_found
  end

  # --- Repeating invoices --------------------------------------------------

  def retainer_invoice(notes: "Monthly retainer")
    InvoiceBuilder.new(
      client: clients(:vertex),
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month,
      issued_on: Date.current,
      notes: notes
    ).call
  end

  test "repeat bills the following month for a retainer" do
    original = retainer_invoice

    assert_difference -> { Invoice.count }, 1 do
      post repeat_invoice_path(original)
    end

    repeated = Invoice.reorder(:id).last
    assert_redirected_to invoice_path(repeated)
    assert_equal Date.current.next_month.beginning_of_month, repeated.period_start
    assert_equal Date.current.next_month.end_of_month, repeated.period_end
    assert_equal original.total, repeated.total
    assert_equal original.notes, repeated.notes
    assert_equal clients(:vertex), repeated.client
  end

  test "repeat works on a paid invoice" do
    original = retainer_invoice
    original.mark_paid!

    assert_difference -> { Invoice.count }, 1 do
      post repeat_invoice_path(original)
    end
  end

  test "repeat refuses to double-bill a period" do
    original = retainer_invoice
    post repeat_invoice_path(original)

    assert_no_difference -> { Invoice.count } do
      post repeat_invoice_path(original)
    end

    assert_redirected_to invoice_path(original)
    assert_match(/already exists/, flash[:alert].to_s)
  end

  test "repeat reports an empty period for an hourly client" do
    assert_no_difference -> { Invoice.count } do
      post repeat_invoice_path(invoices(:acme_old_draft))
    end

    assert_redirected_to invoice_path(invoices(:acme_old_draft))
    assert_match(/No unbilled billable hours/, flash[:alert].to_s)
  end

  test "cannot repeat another user's invoice" do
    assert_no_difference -> { Invoice.count } do
      post repeat_invoice_path(invoices(:rival_old_draft))
    end

    assert_response :not_found
  end

  test "draft_retainers bills whoever is missing this month" do
    # Halcyon already has this month covered, so only Vertex should be drafted.
    InvoiceBuilder.new(
      client: clients(:halcyon),
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month
    ).call

    assert_difference -> { Invoice.count }, 1 do
      post draft_retainers_invoices_path
    end

    assert_redirected_to invoices_path
    assert_match(/Drafted 1 invoice/, flash[:notice].to_s)
    assert_match(/Halcyon Labs/, flash[:notice].to_s)
    assert_equal clients(:vertex), Invoice.reorder(:id).last.client
  end

  test "draft_retainers is a no-op once everything is invoiced" do
    post draft_retainers_invoices_path

    assert_no_difference -> { Invoice.count } do
      post draft_retainers_invoices_path
    end

    assert_match(/Skipped/, flash[:notice].to_s)
  end

  # --- Sending and chasing -------------------------------------------------

  test "deliver emails the invoice and records that it went out" do
    invoice = invoices(:acme_old_draft)

    assert_emails 1 do
      post deliver_invoice_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    invoice.reload
    assert invoice.sent?
    assert_not_nil invoice.sent_at
    assert_match(/emailed to/, flash[:notice].to_s)
  end

  test "deliver refuses when the client has no billing email" do
    clients(:acme).update!(email: nil)
    invoice = invoices(:acme_old_draft)

    assert_emails 0 do
      post deliver_invoice_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    assert_match(/no billing email/, flash[:alert].to_s)
    assert invoice.reload.draft?
  end

  test "deliver reports a delivery failure instead of crashing" do
    invoice = invoices(:acme_old_draft)

    # Point Action Mailer at a closed port so delivery genuinely fails.
    original_method = ActionMailer::Base.delivery_method
    original_settings = ActionMailer::Base.smtp_settings
    ActionMailer::Base.delivery_method = :smtp
    ActionMailer::Base.smtp_settings = { address: "127.0.0.1", port: 1 }

    begin
      post deliver_invoice_path(invoice)
    ensure
      ActionMailer::Base.delivery_method = original_method
      ActionMailer::Base.smtp_settings = original_settings
    end

    assert_redirected_to invoice_path(invoice)
    assert_match(/Could not send the invoice/, flash[:alert].to_s)
    assert invoice.reload.draft?
  end

  test "deliver cannot reach another user's invoice" do
    assert_emails 0 do
      post deliver_invoice_path(invoices(:rival_old_draft))
    end

    assert_response :not_found
  end

  test "remind chases a sent invoice and records the reminder" do
    invoice = invoices(:acme_overdue)

    assert_emails 1 do
      post remind_invoice_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    assert_not_nil invoice.reload.last_reminded_at
    assert_match(/Reminder/, flash[:notice].to_s)
  end

  test "remind refuses on an invoice that was never sent" do
    invoice = invoices(:acme_old_draft)

    assert_emails 0 do
      post remind_invoice_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    assert_match(/Send the invoice before chasing it/, flash[:alert].to_s)
  end

  test "paid invoices cannot be sent or chased" do
    invoice = invoices(:acme_old_paid)

    assert_emails 0 do
      post deliver_invoice_path(invoice)
      post remind_invoice_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    assert_match(/can no longer be changed/, flash[:alert].to_s)
  end

  test "index can filter to overdue invoices" do
    get invoices_path(status: "overdue")

    assert_response :success
    assert_match "INV-202107-001", response.body
    assert_no_match "INV-202001-001", response.body
  end

  test "index reports how much is overdue" do
    get invoices_path

    assert_response :success
    assert_select ".stat__label", /Overdue/
    assert_match "INV-202107-001", response.body
  end

  test "a paid invoice cannot be deleted" do
    invoice = invoices(:acme_old_paid)

    assert_no_difference -> { Invoice.count } do
      delete invoice_path(invoice)
    end

    assert_redirected_to invoice_path(invoice)
    assert_match(/can no longer be changed/, flash[:alert].to_s)
  end

  test "the new invoice preview warns when the period is already invoiced" do
    retainer_invoice

    get new_invoice_path(client_id: clients(:vertex).id)

    assert_response :success
    assert_match(/already exists for an overlapping period/, response.body)
  end
end
