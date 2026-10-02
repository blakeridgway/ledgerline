require "test_helper"

class UserTest < ActiveSupport::TestCase
  test "downcases and strips email_address" do
    user = User.new(email_address: " DOWNCASED@EXAMPLE.COM ")

    assert_equal("downcased@example.com", user.email_address)
  end

  test "billing_name prefers business name, then name, then email" do
    user = users(:blake)

    assert_equal "Blake Consulting LLC", user.billing_name

    user.business_name = nil
    assert_equal "Blake", user.billing_name

    user.name = nil
    assert_equal "blake@example.com", user.billing_name
  end

  test "default_due_date applies the payment terms" do
    assert_equal Date.new(2026, 1, 31), users(:blake).default_due_date(Date.new(2026, 1, 1))
    assert_equal Date.new(2026, 1, 15), users(:other).default_due_date(Date.new(2026, 1, 1))
  end

  test "deleting a user removes their clients and invoices" do
    user = users(:blake)

    assert_difference -> { Client.count } => -user.clients.count,
      -> { Invoice.count } => -user.invoices.count do
      user.destroy
    end
  end
end
