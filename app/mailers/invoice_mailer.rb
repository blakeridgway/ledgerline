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
      from: "#{display_from_name} <#{@user.email_address}>",
      reply_to: @user.email_address,
      subject: subject_line
    )
  end

  private
    # A business name with a newline could otherwise inject a mail header.
    def display_from_name
      @display_from_name ||= @user.billing_name.to_s.gsub(/[\r\n]+/, " ").strip
    end

    def subject_line
      return "Invoice #{@invoice.number} from #{display_from_name}" unless @reminder

      if @invoice.overdue?
        days = @invoice.days_overdue
        "Reminder: invoice #{@invoice.number} is #{days} #{'day'.pluralize(days)} overdue"
      else
        "Reminder: invoice #{@invoice.number} is due #{@invoice.due_on.strftime('%b %-d, %Y')}"
      end
    end
end
