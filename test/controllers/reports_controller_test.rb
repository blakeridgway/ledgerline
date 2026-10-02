require "test_helper"

class ReportsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:blake) }

  test "requires authentication" do
    sign_out

    get reports_path

    assert_redirected_to new_session_path
  end

  test "renders the current year" do
    get reports_path

    assert_response :success
    assert_select "h1", /Profit/
    assert_match(/Net profit/, response.body)
    assert_match(/Estimated tax instalments/, response.body)
  end

  test "accepts a year" do
    get reports_path(year: 2020)

    assert_response :success
    assert_match(/2020/, response.body)
    # The 2020 fixture invoices are for this user only.
    assert_match(/\$1,650\.00/, response.body)
  end

  test "falls back to the current year for a nonsense year" do
    get reports_path(year: "not-a-year")

    assert_response :success
    assert_match(/Next estimated payment/, response.body)
  end

  test "shows income and expenses for the year" do
    InvoiceBuilder.new(
      client: clients(:vertex),
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month,
      issued_on: Date.current
    ).call

    get reports_path(year: Date.current.year)

    assert_response :success
    assert_match(/Finance/, response.body)
    assert_match(/Travel/, response.body)
    assert_match(/Set aside for tax/, response.body)
  end

  test "does not leak another user's figures" do
    get reports_path(year: 2020)

    assert_response :success
    assert_no_match(/Rival Inc/, response.body)
  end
end
