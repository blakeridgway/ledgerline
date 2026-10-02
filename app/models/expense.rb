class Expense < ApplicationRecord
  # Grouped loosely along Schedule C lines — enough to hand to an accountant.
  CATEGORIES = [
    "Advertising",
    "Car and truck",
    "Commissions and fees",
    "Contract labor",
    "Education",
    "Insurance",
    "Legal and professional services",
    "Meals",
    "Office expense",
    "Rent or lease",
    "Repairs and maintenance",
    "Software and subscriptions",
    "Supplies",
    "Taxes and licenses",
    "Travel",
    "Utilities",
    "Other"
  ].freeze

  belongs_to :user
  belongs_to :client, optional: true

  validates :spent_on, presence: true
  validates :vendor, presence: true
  validates :category, presence: true, inclusion: { in: CATEGORIES }
  validates :amount, numericality: { greater_than: 0 }
  # Tagging is reporting-only, but it must still be your own client.
  validate :client_belongs_to_user

  scope :recent_first, -> { order(spent_on: :desc, created_at: :desc) }
  scope :in_period, ->(range) { where(spent_on: range) }

  def self.for_year(year)
    in_period(Date.new(year, 1, 1)..Date.new(year, 12, 31))
  end

  private
    def client_belongs_to_user
      return if client.nil? || client.user_id == user_id

      errors.add(:client, "is not yours")
    end
end
