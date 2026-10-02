require "test_helper"

class ProfilesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:blake) }

  test "show renders business details" do
    get profile_path

    assert_response :success
    assert_select "dd", /Blake Consulting LLC/
  end

  test "edit renders the form" do
    get edit_profile_path

    assert_response :success
  end

  test "update saves business details" do
    patch profile_path, params: { user: {
      business_name: "Blake Studio",
      name: "Blake",
      email_address: "blake@example.com",
      default_currency: "USD",
      default_payment_terms_days: "45",
      expected_hours_per_month: "160",
      default_workday_hours: "7",
      tax_set_aside_percent: "25",
      invoice_prefix: "BS"
    } }

    assert_redirected_to profile_path
    user = users(:blake).reload
    assert_equal "Blake Studio", user.business_name
    assert_equal 45, user.default_payment_terms_days
    assert_equal 160.to_d, user.expected_hours_per_month
    assert_equal 7.to_d, user.default_workday_hours
    assert_equal 25.to_d, user.tax_set_aside_percent
    assert_equal "BS", user.invoice_prefix
  end

  test "update rejects an invalid payment term" do
    patch profile_path, params: { user: { default_payment_terms_days: "-5" } }

    assert_response :unprocessable_entity
  end
end
