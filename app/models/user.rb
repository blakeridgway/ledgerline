class User < ApplicationRecord
  has_secure_password
  has_many :sessions, dependent: :destroy

  has_many :clients, dependent: :destroy
  has_many :time_entries, through: :clients
  has_many :invoices, dependent: :destroy
  has_many :expenses, dependent: :destroy

  normalizes :email_address, with: ->(e) { e.strip.downcase }

  validates :email_address, presence: true, uniqueness: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }
  validates :invoice_prefix, presence: true, length: { maximum: 20 },
    format: { with: /\A[A-Za-z0-9._-]+\z/, message: "may only contain letters, numbers, dots, dashes and underscores" }
  validates :default_payment_terms_days, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :expected_hours_per_month, numericality: { greater_than_or_equal_to: 0 }
  validates :tax_set_aside_percent, numericality: { greater_than_or_equal_to: 0, less_than_or_equal_to: 100 }

  # Name shown as the "from" contact on invoices, falling back to the login email.
  def billing_name
    business_name.presence || name.presence || email_address
  end

  def default_due_date(from = Date.current)
    from + default_payment_terms_days.to_i
  end
end
