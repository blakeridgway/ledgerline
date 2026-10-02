require "test_helper"

class DashboardControllerTest < ActionDispatch::IntegrationTest
  test "requires authentication" do
    get root_path

    assert_redirected_to new_session_path
  end

  test "renders the dashboard for a signed in user" do
    sign_in_as users(:blake)

    get root_path

    assert_response :success
    assert_select "h1", "Dashboard"
    assert_select "td", /Acme Corp/
    assert_select "td", /Finance/
  end

  test "does not leak another user's data" do
    sign_in_as users(:blake)

    get root_path

    assert_no_match "Rival Inc", response.body
  end

  test "surfaces overdue invoices" do
    sign_in_as users(:blake)

    get root_path

    assert_response :success
    assert_match "INV-202107-001", response.body
    assert_match(/overdue/, response.body)
  end

  test "voided invoices are excluded from this month's invoiced total" do
    sign_in_as users(:blake)
    invoice = InvoiceBuilder.new(
      client: clients(:vertex),
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month,
      issued_on: Date.current
    ).call

    get root_path
    assert_match(%r{Invoiced this month</div>\s*<div class="stat__value">\$6,000\.00}, response.body)

    invoice.void!
    get root_path
    assert_match(%r{Invoiced this month</div>\s*<div class="stat__value">\$0\.00}, response.body)
  end
end
