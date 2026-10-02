# Emails an invoice to the client with the PDF attached, so they have
# everything in one message.
class InvoiceMailer < ApplicationMailer
  def invoice(invoice, reminder: false)
    @invoice = invoice
    @client = invoice.client
    @user = invoice.user
    @reminder = reminder

    attachments["#{invoice.number}.pdf"] = {
      mime_type: "application/pdf",
      content: InvoicePdf.new(invoice).render
    }

    mail(
      to: @client.email,
      from: "#{@user.billing_name} <#{@user.email_address}>",
      reply_to: @user.email_address,
      subject: subject_line
    )
  end

  private
    def subject_line
      return "Invoice #{@invoice.number} from #{@user.billing_name}" unless @reminder

      if @invoice.overdue?
        days = @invoice.days_overdue
        "Reminder: invoice #{@invoice.number} is #{days} #{'day'.pluralize(days)} overdue"
      else
        "Reminder: invoice #{@invoice.number} is due #{@invoice.due_on.strftime('%b %-d, %Y')}"
      end
    end
end
