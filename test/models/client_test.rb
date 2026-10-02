require "test_helper"

class ClientTest < ActiveSupport::TestCase
  setup do
    @user = users(:blake)
    @acme = clients(:acme)
  end

  test "is valid with the fixture data" do
    assert @acme.valid?
  end

  test "hourly client requires a positive hourly rate" do
    client = @user.clients.new(name: "Unpriced Co", billing_type: "hourly", hourly_rate: 0)

    assert_not client.valid?
    assert_includes client.errors[:hourly_rate], "must be greater than 0"
  end

  test "monthly client requires a positive monthly rate" do
    client = @user.clients.new(name: "Unpriced Retainer", billing_type: "monthly", monthly_rate: 0)

    assert_not client.valid?
    assert_includes client.errors[:monthly_rate], "must be greater than 0"
  end

  test "monthly client is not required to have an hourly rate" do
    client = @user.clients.new(name: "Retainer Co", billing_type: "monthly", monthly_rate: 5000)

    assert client.valid?, client.errors.full_messages.to_sentence
  end

  test "rejects an unknown billing type" do
    client = @user.clients.new(name: "Weekly Co", billing_type: "weekly", hourly_rate: 100)

    assert_not client.valid?
    assert_includes client.errors[:billing_type], "is not included in the list"
  end

  test "name must be unique per user" do
    duplicate = @user.clients.new(name: @acme.name, billing_type: "hourly", hourly_rate: 10)

    assert_not duplicate.valid?
    assert_includes duplicate.errors[:name], "has already been taken"
  end

  test "two users may have clients with the same name" do
    other = clients(:rival).user.clients.new(name: @acme.name, billing_type: "hourly", hourly_rate: 10)

    assert other.valid?, other.errors.full_messages.to_sentence
  end

  test "display_name prefers the company when present" do
    assert_equal "Acme Corp", @acme.display_name
    assert_equal "Finance", clients(:vertex).display_name
  end

  test "defaults the currency to the owner's default" do
    client = @user.clients.new(name: "No Currency Co", billing_type: "hourly", hourly_rate: 10)

    client.valid?

    assert_equal "USD", client.currency
  end

  test "unbilled_hours counts only billable uninvoiced hours" do
    # 2.5 + 3.5 this month, 4 last month, plus 1 non-billable that must not count.
    assert_equal 10.to_d, @acme.unbilled_hours
  end

  test "unbilled_hours accepts a date range" do
    assert_equal 6.to_d, @acme.unbilled_hours(Date.current.all_month)
  end

  test "rate_label renders the rate for the billing type" do
    assert_equal "$150.00/hr", @acme.rate_label
    assert_equal "$6,000.00/mo", clients(:vertex).rate_label
  end

  test "a retainer with expected hours has a target and an effective hourly rate" do
    vertex = clients(:vertex)

    assert vertex.hours_target?
    assert_equal 37.5.to_d, vertex.effective_hourly_rate
  end

  test "a retainer without expected hours has no target" do
    halcyon = clients(:halcyon)

    assert_not halcyon.hours_target?
    assert_nil halcyon.effective_hourly_rate
  end

  test "an hourly client never has an hours target" do
    assert_not @acme.hours_target?
    assert_nil @acme.effective_hourly_rate
  end

  test "expected hours cannot be negative" do
    client = @user.clients.new(
      name: "Negative Co", billing_type: "monthly", monthly_rate: 100,
      expected_hours_per_month: -1
    )

    assert_not client.valid?
    assert_includes client.errors[:expected_hours_per_month], "must be greater than or equal to 0"
  end

  test "unbilled_entries_for is chronological and within the period" do
    entries = @acme.unbilled_entries_for(Date.current.beginning_of_month, Date.current.end_of_month)

    assert_equal [ "Discovery workshop", "Data model review" ], entries.map(&:summary)
  end

  test "rejects a malformed billing email" do
    client = @user.clients.new(name: "Bad Email Co", billing_type: "hourly", hourly_rate: 10, email: "nope")

    assert_not client.valid?
    assert_includes client.errors[:email], "is not a valid email address"
  end
end
