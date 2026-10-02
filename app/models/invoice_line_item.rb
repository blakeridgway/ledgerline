class InvoiceLineItem < ApplicationRecord
  KINDS = %w[hourly monthly].freeze

  belongs_to :invoice, inverse_of: :invoice_line_items
  belongs_to :time_entry, optional: true

  enum :kind, { hourly: "hourly", monthly: "monthly" }, validate: true

  validates :description, presence: true
  validates :quantity, :unit_rate, :amount, numericality: true

  def service_date
    time_entry&.worked_on || invoice.period_end
  end
end
