require "test_helper"

class InvoiceMailerTest < ActionMailer::TestCase
  setup do
    @invoice = invoices(:acme_overdue)
  end

  test "emails the client with the invoice PDF attached" do
    mail = InvoiceMailer.invoice(@invoice)

    assert_equal [ @invoice.client.email ], mail.to
    assert_equal [ @invoice.user.email_address ], mail.reply_to
    assert_match @invoice.number, mail.subject
    assert_match @invoice.user.billing_name, mail.subject

    attachment = mail.attachments["#{@invoice.number}.pdf"]
    assert_not_nil attachment, "expected the invoice PDF to be attached"
    assert_equal "application/pdf", attachment.mime_type
    assert attachment.body.decoded.start_with?("%PDF")
  end

  test "the body carries the amount and the payment instructions" do
    mail = InvoiceMailer.invoice(@invoice)
    body = mail.body.encoded

    assert_includes body, "$900.00"
    assert_includes body, "Payment instructions"
    assert_includes body, "ACH transfer"
  end

  test "reminder subject says how overdue it is" do
    mail = InvoiceMailer.invoice(@invoice, reminder: true)

    assert_match(/Reminder/, mail.subject)
    assert_match(/overdue/, mail.subject)
  end

  test "reminder subject quotes the due date when it is not yet late" do
    invoice = invoices(:acme_overdue)
    invoice.update!(due_on: Date.current + 5.days)

    mail = InvoiceMailer.invoice(invoice, reminder: true)

    assert_match(/is due/, mail.subject)
    assert_match(invoice.due_on.strftime("%b %-d, %Y"), mail.subject)
  end

  test "delivers" do
    assert_emails 1 do
      InvoiceMailer.invoice(@invoice).deliver_now
    end
  end
end
