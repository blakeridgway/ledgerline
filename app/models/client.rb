class Client < ApplicationRecord
  BILLING_TYPES = %w[hourly monthly].freeze

  belongs_to :user
  has_many :time_entries, dependent: :destroy
  has_many :invoices, dependent: :destroy
  # Expenses are never invoiced, so removing a client just untags them.
  has_many :expenses, dependent: :nullify

  enum :billing_type, { hourly: "hourly", monthly: "monthly" }, validate: true

  validates :name, presence: true, uniqueness: { scope: :user_id }
  validates :email, allow_blank: true,
    format: { with: URI::MailTo::EMAIL_REGEXP, message: "is not a valid email address" }
  validates :hourly_rate, :monthly_rate,
    numericality: { greater_than_or_equal_to: 0 }
  validates :expected_hours_per_month, numericality: { greater_than_or_equal_to: 0 }
  validates :hourly_rate, numericality: { greater_than: 0 }, if: :hourly?
  validates :monthly_rate, numericality: { greater_than: 0 }, if: :monthly?

  scope :active, -> { where(active: true) }
  scope :alphabetical, -> { order(Arel.sql("LOWER(name) ASC")) }

  before_validation :apply_default_currency

  def display_name
    company.presence || name
  end

  def effective_currency
    currency.presence || user&.default_currency.presence || "USD"
  end

  def rate
    hourly? ? hourly_rate : monthly_rate
  end

  def rate_label
    if hourly?
      "#{ActiveSupport::NumberHelper.number_to_currency(hourly_rate, unit: currency_symbol)}/hr"
    else
      "#{ActiveSupport::NumberHelper.number_to_currency(monthly_rate, unit: currency_symbol)}/mo"
    end
  end

  # A monthly retainer that carries an hours commitment, e.g. 160 hrs/month.
  def hours_target?
    monthly? && expected_hours_per_month.to_d.positive?
  end

  # The flat retainer expressed hourly across the expected hours, which is the
  # number that matters when the pay is a salary rather than an hourly rate.
  def effective_hourly_rate
    return nil unless hours_target?

    (monthly_rate.to_d / expected_hours_per_month.to_d).round(2)
  end

  def timesheet_for(month = Date.current)
    Timesheet.for_month(self, month)
  end

  def currency_symbol
    case effective_currency
    when "USD" then "$"
    when "EUR" then "€"
    when "GBP" then "£"
    else "#{effective_currency} "
    end
  end

  # Billable hours logged in an optional date range.
  def unbilled_hours(range = nil)
    scope = time_entries.billable.unbilled
    scope = scope.in_period(range) if range
    scope.sum(:hours)
  end

  # Unbilled entries that would be swept onto an invoice for the given period.
  def unbilled_entries_for(period_start, period_end)
    time_entries.billable.unbilled.in_period(period_start..period_end).chronological
  end

  private
    def apply_default_currency
      self.currency = user&.default_currency if currency.blank?
    end
end
