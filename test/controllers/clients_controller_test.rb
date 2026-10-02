require "test_helper"

class ClientsControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:blake) }

  test "index lists the signed in user's clients" do
    get clients_path

    assert_response :success
    assert_select "td", /Acme Corp/
    assert_no_match "Rival Inc", response.body
  end

  test "index can show archived clients" do
    clients(:acme).update!(active: false)

    get clients_path(status: "archived")

    assert_response :success
    assert_select "td", /Acme Corp/
  end

  test "show renders a client" do
    get client_path(clients(:acme))

    assert_response :success
    assert_select "h1", "Acme Corp"
  end

  test "show paginates time entries" do
    get client_path(clients(:acme), page: 2)

    assert_response :success
  end

  test "new renders the form" do
    get new_client_path

    assert_response :success
  end

  test "create adds a client" do
    assert_difference -> { Client.count }, 1 do
      post clients_path, params: { client: {
        name: "Fresh Co", billing_type: "hourly", hourly_rate: "200",
        currency: "USD", active: "1"
      } }
    end

    client = Client.order(:id).last
    assert_equal "Fresh Co", client.name
    assert_redirected_to client_path(client)
  end

  test "create re-renders on invalid input" do
    assert_no_difference -> { Client.count } do
      post clients_path, params: { client: { name: "", billing_type: "hourly", hourly_rate: "0" } }
    end

    assert_response :unprocessable_entity
  end

  test "update archives a client" do
    patch client_path(clients(:acme)), params: { client: { active: "0" } }

    assert_redirected_to client_path(clients(:acme))
    assert_not clients(:acme).reload.active?
  end

  test "destroy removes a client" do
    client = users(:blake).clients.create!(name: "Disposable Co", billing_type: "hourly", hourly_rate: 10)

    assert_difference -> { Client.count }, -1 do
      delete client_path(client)
    end

    assert_redirected_to clients_path
  end

  test "cannot reach another user's client" do
    get client_path(clients(:rival))
    assert_response :not_found

    get edit_client_path(clients(:rival))
    assert_response :not_found

    assert_no_difference -> { Client.count } do
      delete client_path(clients(:rival))
    end
    assert_response :not_found
  end

  # --- Retainer hours / timesheet ------------------------------------------

  test "new client form prefills retainer hours from the profile" do
    get new_client_path

    assert_response :success
    input = css_select("input[name='client[expected_hours_per_month]']").first
    assert_equal "160.0", input["value"]
  end

  test "create stores a retainer hours commitment" do
    assert_difference -> { Client.count }, 1 do
      post clients_path, params: { client: {
        name: "Retainer Co", billing_type: "monthly", monthly_rate: "4000",
        expected_hours_per_month: "160", currency: "USD", active: "1"
      } }
    end

    client = Client.order(:id).last
    assert_equal 160.to_d, client.expected_hours_per_month
    assert client.hours_target?
  end

  test "timesheet renders the current month" do
    get timesheet_client_path(clients(:vertex))

    assert_response :success
    assert_select "h1", "Timesheet"
    assert_select "td", /Sprint planning/
    assert_select "td", /Code review/
  end

  test "timesheet accepts a month" do
    get timesheet_client_path(clients(:vertex), month: (Date.current - 1.month).strftime("%Y-%m"))

    assert_response :success
    assert_match(/No billable hours in this month/, response.body)
  end

  test "timesheet ignores an impossible month" do
    get timesheet_client_path(clients(:vertex), month: "2026-13")

    assert_response :success
    assert_select "td", /Sprint planning/
  end

  test "timesheet collapses a day's entries into one row with a total" do
    get timesheet_client_path(clients(:vertex))

    assert_response :success
    # Two days of entries collapse to two rows: 4 hours, then 4 + 3.5 = 7.5.
    assert_select "tbody tr", 2
    assert_match(/Code review/, response.body)
    assert_match(/Sprint planning/, response.body)
    assert_match(/7\.5/, response.body)
    assert_match(/148.5 hrs to go/, response.body)
  end

  test "timesheet serves a PDF" do
    get timesheet_client_path(clients(:vertex), format: :pdf)

    assert_response :success
    assert_equal "application/pdf", response.media_type
    assert response.body.start_with?("%PDF")
  end

  test "timesheet works for an hourly client as a plain hours log" do
    get timesheet_client_path(clients(:acme))

    assert_response :success
    assert_match(/Discovery workshop/, response.body)
    assert_match(/Logged hours/, response.body)
    assert_no_match(/Retainer/, response.body)
  end

  test "timesheet is not reachable for another user's client" do
    get timesheet_client_path(clients(:rival))
    assert_response :not_found

    get timesheet_client_path(clients(:rival), format: :pdf)
    assert_response :not_found
  end
end
