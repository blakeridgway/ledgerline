require "test_helper"

class TimeEntriesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:blake) }

  test "index lists entries" do
    get time_entries_path

    assert_response :success
    assert_select "td", /Discovery workshop/
    assert_no_match "Other tenant work", response.body
  end

  test "index filters by client" do
    get time_entries_path(client_id: clients(:vertex).id)

    assert_response :success
    assert_match "Architecture review", response.body
    assert_no_match "Discovery workshop", response.body
  end

  test "index filters by billing status" do
    get time_entries_path(status: "unbilled")

    assert_response :success
    assert_match "Discovery workshop", response.body
  end

  test "index filters by date range" do
    get time_entries_path(from: 5.years.ago.to_date, to: 4.years.ago.to_date)

    assert_response :success
    assert_no_match "Discovery workshop", response.body
  end

  test "create logs time against a client" do
    assert_difference -> { TimeEntry.count }, 1 do
      post time_entries_path, params: { time_entry: {
        client_id: clients(:acme).id, worked_on: Date.current,
        hours: "2.25", description: "Pairing session", billable: "1"
      } }
    end

    entry = TimeEntry.order(:id).last
    assert_equal 2.25.to_d, entry.hours
    assert_redirected_to time_entries_path
  end

  test "create honours return_to" do
    post time_entries_path, params: {
      return_to: root_path,
      time_entry: {
        client_id: clients(:acme).id, worked_on: Date.current,
        hours: "1", description: "Quick fix", billable: "1"
      }
    }

    assert_redirected_to root_path
  end

  test "create ignores an external return_to" do
    post time_entries_path, params: {
      return_to: "https://evil.example/phish",
      time_entry: {
        client_id: clients(:acme).id, worked_on: Date.current,
        hours: "1", description: "Quick fix", billable: "1"
      }
    }

    assert_redirected_to time_entries_path
  end

  test "create rejects non positive hours" do
    assert_no_difference -> { TimeEntry.count } do
      post time_entries_path, params: { time_entry: {
        client_id: clients(:acme).id, worked_on: Date.current, hours: "0"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "update edits an entry" do
    entry = time_entries(:acme_unbilled_a)

    patch time_entry_path(entry), params: { time_entry: { hours: "5" } }

    assert_redirected_to time_entries_path
    assert_equal 5.to_d, entry.reload.hours
  end

  test "destroy removes an entry" do
    entry = time_entries(:acme_unbilled_a)

    assert_difference -> { TimeEntry.count }, -1 do
      delete time_entry_path(entry)
    end

    assert_redirected_to time_entries_path
  end

  test "billed entries cannot be edited or deleted" do
    invoice = InvoiceBuilder.new(
      client: clients(:acme),
      period_start: Date.current.beginning_of_month,
      period_end: Date.current.end_of_month
    ).call
    entry = invoice.time_entries.first
    assert_not_nil entry

    get edit_time_entry_path(entry)
    assert_redirected_to time_entries_path

    patch time_entry_path(entry), params: { time_entry: { hours: "99" } }
    assert_redirected_to time_entries_path
    assert_not_equal 99.to_d, entry.reload.hours

    assert_no_difference -> { TimeEntry.count } do
      delete time_entry_path(entry)
    end
    assert_redirected_to time_entries_path
    assert_not_nil entry.reload.invoice_id
  end

  test "cannot log time against another user's client" do
    assert_no_difference -> { TimeEntry.count } do
      post time_entries_path, params: { time_entry: {
        client_id: clients(:rival).id, worked_on: Date.current, hours: "1"
      } }
    end

    assert_response :not_found
  end

  test "cannot edit another user's entry" do
    get edit_time_entry_path(time_entries(:rival_entry))

    assert_response :not_found
  end

  # --- Week grid -----------------------------------------------------------

  test "batch renders a seven day grid" do
    get batch_time_entries_path(client_id: clients(:acme).id)

    assert_response :success
    assert_select "h1", "Log a week"
    assert_select "tbody tr", 7
  end

  test "batch defaults to the current week" do
    get batch_time_entries_path(client_id: clients(:acme).id)

    assert_response :success
    assert_match Date.current.beginning_of_week(:monday).strftime("%-d %b"), response.body
  end

  test "batch accepts a week and a client" do
    week = Date.current.beginning_of_week(:monday) - 1.week

    get batch_time_entries_path(client_id: clients(:vertex).id, week_start: week)

    assert_response :success
    assert_match week.strftime("%-d %b"), response.body
    assert_match(/Finance/, response.body)
  end

  test "batch shows a retainer's progress" do
    get batch_time_entries_path(client_id: clients(:vertex).id)

    assert_response :success
    assert_match(/Retainer progress/, response.body)
    assert_match(/of 160 hours/, response.body)
  end

  test "save_batch logs every day with hours and skips blanks" do
    client = clients(:acme)
    week = Date.current.beginning_of_week(:monday) - 8.weeks

    assert_difference -> { TimeEntry.count }, 3 do
      post save_batch_time_entries_path, params: {
        client_id: client.id, week_start: week, billable: "1",
        days: {
          "0" => { worked_on: week, hours: "8", description: "Monday" },
          "1" => { worked_on: week + 1.day, hours: "", description: "blank" },
          "2" => { worked_on: week + 2.day, hours: "6.5", description: "Wednesday" },
          "3" => { worked_on: week + 3.day, hours: "0", description: "zero" },
          "4" => { worked_on: week + 4.day, hours: "4", description: "Friday" }
        }
      }
    end

    assert_redirected_to batch_time_entries_path(client_id: client.id, week_start: week)
    assert_equal 18.5.to_d, client.time_entries.in_period(week..(week + 4.days)).sum(:hours)
    assert_equal "Monday", client.time_entries.find_by(worked_on: week).description
  end

  test "save_batch honours the billable flag" do
    client = clients(:acme)
    week = Date.current.beginning_of_week(:monday) - 8.weeks

    post save_batch_time_entries_path, params: {
      client_id: client.id, week_start: week, billable: "0",
      days: { "0" => { worked_on: week, hours: "2", description: "Internal" } }
    }

    assert_not client.time_entries.find_by(worked_on: week).billable?
  end

  test "save_batch reports a typo instead of silently dropping it" do
    client = clients(:acme)
    week = Date.current.beginning_of_week(:monday) - 8.weeks

    assert_difference -> { TimeEntry.count }, 1 do
      post save_batch_time_entries_path, params: {
        client_id: client.id, week_start: week, billable: "1",
        days: {
          "0" => { worked_on: week, hours: "eight", description: "typo" },
          "1" => { worked_on: week + 1.day, hours: "3", description: "valid" }
        }
      }
    end

    assert_match(/not a number/, flash[:alert].to_s)
    assert_equal 3.to_d, client.time_entries.in_period((week + 1.day)..(week + 1.day)).sum(:hours)
  end

  test "save_batch with nothing entered says so" do
    assert_no_difference -> { TimeEntry.count } do
      post save_batch_time_entries_path, params: {
        client_id: clients(:acme).id,
        week_start: Date.current.beginning_of_week(:monday),
        billable: "1",
        days: { "0" => { worked_on: Date.current, hours: "", description: "" } }
      }
    end

    assert_redirected_to batch_time_entries_path(client_id: clients(:acme).id, week_start: Date.current.beginning_of_week(:monday))
    assert_match(/at least one day/, flash[:alert].to_s)
  end

  test "cannot batch against another user's client" do
    post save_batch_time_entries_path, params: {
      client_id: clients(:rival).id, week_start: Date.current, billable: "1",
      days: { "0" => { worked_on: Date.current, hours: "1", description: "" } }
    }

    assert_response :not_found
  end

  test "the edit form does not offer a client change" do
    get edit_time_entry_path(time_entries(:acme_unbilled_a))

    assert_response :success
    assert_select "select[name='time_entry[client_id]']", count: 0
    assert_match "Acme Corp", response.body
  end
end
