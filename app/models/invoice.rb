class Invoice < ApplicationRecord
  STATUSES = %w[draft sent paid void].freeze

  belongs_to :user
  belongs_to :client
  has_many :invoice_line_items, -> { order(:id) }, dependent: :destroy, inverse_of: :invoice
  has_many :time_entries, dependent: :nullify

  enum :status, { draft: "draft", sent: "sent", paid: "paid", void: "void" }, validate: true

  validates :number, presence: true, uniqueness: { scope: :user_id }
  validates :period_start, :period_end, :issued_on, presence: true
  validate :period_end_after_period_start
  validate :period_does_not_overlap

  scope :recent_first, -> { order(period_end: :desc, created_at: :desc) }
  scope :open_invoices, -> { where(status: %w[draft sent]) }
  # Non-void invoices whose period intersects the given one. Matching on an
  # intersection (not an exact pair) stops a retainer being billed twice by
  # shifting the period a day.
  scope :overlapping, ->(period_start, period_end) {
    where.not(status: "void")
      .where("period_start <= ? AND period_end >= ?", period_end, period_start)
  }

  # Sent, unpaid, and past the due date.
  scope :overdue, -> { sent.where(due_on: ...Date.current) }
  # Sent, unpaid, due within the next `within` window.
  scope :due_soon, ->(within = 7.days) { sent.where(due_on: Date.current..(Date.current + within)) }
  # Everything a client currently owes (sent but not yet paid).
  scope :awaiting_payment, -> { sent }

  def self.next_number_for(user, on_date = Date.current)
    prefix = "#{user.invoice_prefix.to_s.strip.presence || 'INV'}-#{on_date.strftime('%Y%m')}"
    existing = user.invoices.where("number LIKE ?", "#{prefix}-%").pluck(:number)
    sequence = existing.filter_map { |n| n.split("-").last.to_i }.max.to_i + 1
    format("%s-%03d", prefix, sequence)
  end

  def period_label
    "#{period_start.strftime('%b %-d, %Y')} – #{period_end.strftime('%b %-d, %Y')}"
  end

  # True when the period is exactly one calendar month, which is how retainers
  # are billed.
  def calendar_month?
    period_start == period_start.beginning_of_month && period_end == period_start.end_of_month
  end

  # The period that follows this one, keeping its shape: the next calendar month
  # for monthly periods, or the same number of days for anything else.
  def next_period
    if calendar_month?
      start = period_start.next_month
      [ start, start.end_of_month ]
    else
      start = period_end + 1.day
      [ start, start + (period_end - period_start).days ]
    end
  end

  def hours_total
    invoice_line_items.hourly.sum(:quantity)
  end

  def mark_paid!(date = Date.current)
    update!(status: "paid", paid_at: date.in_time_zone)
  end

  # Records that the invoice went to the client. Status and timestamp are set in
  # one write so a failure can't leave a sent invoice with no sent_at.
  def mark_sent!(time = Time.current)
    update!(status: "sent", sent_at: time)
  end

  # True when the invoice is with the client and past its due date.
  def overdue?
    sent? && due_on.present? && due_on < Date.current
  end

  def days_overdue
    overdue? ? (Date.current - due_on).to_i : 0
  end

  # True when payment is due shortly but not yet late.
  def due_soon?(within = 7.days)
    sent? && due_on.present? && !overdue? && due_on <= Date.current + within
  end

  def days_until_due
    due_on.present? ? (due_on - Date.current).to_i : 0
  end

  def reminded?
    last_reminded_at.present?
  end

  # Voiding keeps the invoice for your records but releases its hours so they
  # can be billed on a corrected invoice.
  def void!
    transaction do
      time_entries.update_all(invoice_id: nil)
      update!(status: "void")
    end
  end

  def outstanding?
    draft? || sent?
  end

  private
    def period_end_after_period_start
      return if period_start.blank? || period_end.blank?
      errors.add(:period_end, "must be on or after the period start") if period_end < period_start
    end

    def period_does_not_overlap
      return if client.nil? || period_start.blank? || period_end.blank? || void?

      scope = client.invoices.overlapping(period_start, period_end)
      scope = scope.where.not(id: id) if persisted?
      errors.add(:base, "An invoice already exists for an overlapping period") if scope.exists?
    end
end
