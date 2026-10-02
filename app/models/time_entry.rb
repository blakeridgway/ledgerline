class TimeEntry < ApplicationRecord
  belongs_to :client
  belongs_to :invoice, optional: true

  delegate :user, :display_name, :hourly_rate, :currency_symbol, to: :client

  validates :worked_on, presence: true
  validates :hours, presence: true, numericality: { greater_than: 0 }
  validates :break_minutes, numericality: { only_integer: true, greater_than_or_equal_to: 0 }
  validates :description, length: { maximum: 500 }, allow_blank: true

  before_validation { self.break_minutes = 0 if break_minutes.blank? }

  scope :billable, -> { where(billable: true) }
  scope :unbilled, -> { where(invoice_id: nil) }
  scope :billed, -> { where.not(invoice_id: nil) }
  scope :chronological, -> { order(worked_on: :asc, created_at: :asc) }
  scope :recent_first, -> { order(worked_on: :desc, created_at: :desc) }
  scope :in_period, ->(range) { where(worked_on: range) }

  # Billed value at the client's current hourly rate. Hours logged against a
  # monthly retainer are informational, so they carry no hourly value.
  def amount
    return 0.to_d unless billable?
    return 0.to_d if client.monthly?

    (hours.to_d * hourly_rate.to_d).round(2)
  end

  # Break time is recorded for the timesheet only; `hours` is already net of it.
  def break_hours
    break_minutes.to_d / 60
  end

  def summary
    description.presence || "Time entry"
  end
end
