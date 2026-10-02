module ApplicationHelper
  # Formats hours without trailing zeros: 8 -> "8", 7.5 -> "7.5", 1.25 -> "1.25"
  def hours_label(value)
    ActiveSupport::NumberHelper.number_to_rounded(value, precision: 2, strip_insignificant_zeros: true)
  end

  def money(value, currency = nil)
    symbol = currency.presence || "USD"
    ActiveSupport::NumberHelper.number_to_currency(value, unit: currency_symbol(symbol))
  end

  def currency_symbol(currency)
    case currency.to_s
    when "USD" then "$"
    when "EUR" then "€"
    when "GBP" then "£"
    else "#{currency} "
    end
  end

  def date_label(date)
    date&.strftime("%b %-d, %Y").to_s
  end

  def invoice_status_badge(status)
    tone = { "draft" => "neutral", "sent" => "info", "paid" => "success", "void" => "muted" }.fetch(status, "neutral")
    tag.span(status.titleize, class: "badge badge--#{tone}")
  end

  # Overdue and due-soon read as badges; everything else is just the date.
  def invoice_due_label(invoice)
    return tag.span("—", class: "muted") if invoice.due_on.blank?

    if invoice.overdue?
      days = invoice.days_overdue
      tag.span("#{days} #{'day'.pluralize(days)} overdue", class: "badge badge--danger")
    elsif invoice.due_soon?
      days = invoice.days_until_due
      tag.span(days.zero? ? "Due today" : "Due in #{days} #{'day'.pluralize(days)}", class: "badge badge--warn")
    else
      tag.span(date_label(invoice.due_on), class: "muted")
    end
  end

  def nav_link(label, path, controller:)
    active = controller_name == controller
    link_to label, path, class: class_names("nav__link", "is-active": active)
  end

  # --- Retainer hour commitments -------------------------------------------

  # "152 / 160 hrs"
  def retainer_progress_text(timesheet)
    "#{hours_label(timesheet.total_hours)} / #{hours_label(timesheet.expected_hours)} hrs"
  end

  # "8 hrs to go" / "4.5 hrs over" / "complete"
  def retainer_remaining_text(timesheet)
    return "complete" if timesheet.complete?

    "#{hours_label(timesheet.remaining_hours)} hrs to go"
  end

  def retainer_progress_bar(timesheet)
    progress_bar(timesheet.progress_percent)
  end

  def progress_bar(percent)
    value = percent.to_i.clamp(0, 100)

    tag.div(class: "progress", role: "progressbar",
            "aria-valuenow": percent.to_i, "aria-valuemin": 0, "aria-valuemax": 100) do
      tag.div(class: class_names("progress__bar", "is-complete": percent.to_i >= 100),
              style: "width: #{value}%")
    end
  end
end
