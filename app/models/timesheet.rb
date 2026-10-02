# A period of billable hours for one client, with the retainer commitment
# applied. Drives both the on-screen progress displays and the timesheet PDF.
#
# Hours are counted from entries logged in the period rather than from entries
# attached to an invoice, so a timesheet is still correct when hours are logged
# after the invoice for that month was already raised.
class Timesheet
  Day = Struct.new(:date, :hours, :descriptions, keyword_init: true) do
    def description
      descriptions.join(" · ")
    end
  end

  attr_reader :client, :period_start, :period_end

  def initialize(client:, period_start:, period_end:)
    @client = client
    @period_start = period_start.to_date
    @period_end = period_end.to_date
  end

  def self.for_month(client, month = Date.current)
    new(client: client, period_start: month.beginning_of_month, period_end: month.end_of_month)
  end

  def entries
    @entries ||= client.time_entries.billable.in_period(period).order(:worked_on, :created_at).to_a
  end

  def days
    @days ||= entries.group_by(&:worked_on).sort.map do |date, group|
      Day.new(
        date: date,
        hours: group.sum { |entry| entry.hours.to_d },
        descriptions: group.map(&:summary).uniq
      )
    end
  end

  def total_hours
    @total_hours ||= entries.sum { |entry| entry.hours.to_d }
  end

  def non_billable_hours
    @non_billable_hours ||= client.time_entries
      .where(billable: false)
      .in_period(period)
      .sum(:hours).to_d
  end

  def days_logged
    days.size
  end

  # True when the client is a retainer with an hours commitment (e.g. 160/mo).
  def target?
    client.hours_target?
  end

  def expected_hours
    client.expected_hours_per_month.to_d
  end

  def remaining_hours
    return nil unless target?

    [ expected_hours - total_hours, 0 ].max
  end

  def over_hours
    return 0.to_d unless target?

    [ total_hours - expected_hours, 0 ].max.to_d
  end

  def progress_percent
    return nil unless target?

    (total_hours / expected_hours * 100).round
  end

  def complete?
    target? && remaining_hours.zero?
  end

  def period
    period_start..period_end
  end

  def month_label
    period_end.strftime("%B %Y")
  end

  def period_label
    "#{period_start.strftime('%b %-d, %Y')} – #{period_end.strftime('%b %-d, %Y')}"
  end
end
