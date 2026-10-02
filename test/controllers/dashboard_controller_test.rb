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
end
