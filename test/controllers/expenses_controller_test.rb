require "test_helper"

class ExpensesControllerTest < ActionDispatch::IntegrationTest
  setup { sign_in_as users(:blake) }

  test "index lists this year's expenses" do
    get expenses_path

    assert_response :success
    assert_select "h1", "Expenses"
    assert_match "Figma", response.body
    assert_no_match "Someone else", response.body
  end

  test "index filters by category" do
    get expenses_path(category: "Travel")

    assert_response :success
    assert_match "Delta", response.body
    assert_no_match "Figma", response.body
  end

  test "index filters by client" do
    get expenses_path(client_id: clients(:acme).id)

    assert_response :success
    assert_match "Delta", response.body
    assert_no_match "Figma", response.body
  end

  test "new renders the form" do
    get new_expense_path

    assert_response :success
    assert_select "select[name='expense[category]']"
  end

  test "create records an expense" do
    assert_difference -> { Expense.count }, 1 do
      post expenses_path, params: { expense: {
        spent_on: Date.current, vendor: "AWS",
        category: "Software and subscriptions", amount: "120.50"
      } }
    end

    assert_redirected_to expenses_path(year: Date.current.year)
    assert_equal 120.5.to_d, Expense.order(:id).last.amount
  end

  test "create rejects a category outside the schedule" do
    assert_no_difference -> { Expense.count } do
      post expenses_path, params: { expense: {
        spent_on: Date.current, vendor: "Marina", category: "Yacht", amount: "10"
      } }
    end

    assert_response :unprocessable_entity
  end

  test "update edits an expense" do
    expense = expenses(:software)

    patch expense_path(expense), params: { expense: { amount: "60" } }

    assert_redirected_to expenses_path(year: expense.spent_on.year)
    assert_equal 60.to_d, expense.reload.amount
  end

  test "destroy removes an expense" do
    expense = expenses(:software)

    assert_difference -> { Expense.count }, -1 do
      delete expense_path(expense)
    end

    assert_redirected_to expenses_path(year: expense.spent_on.year)
  end

  test "create rejects another user's client tag" do
    assert_no_difference -> { Expense.count } do
      post expenses_path, params: { expense: {
        spent_on: Date.current, vendor: "Sketchy", category: "Other", amount: "10",
        client_id: clients(:rival).id
      } }
    end

    assert_response :unprocessable_entity
  end

  test "cannot reach another user's expense" do
    other = expenses(:other_user_expense)

    get edit_expense_path(other)
    assert_response :not_found

    assert_no_difference -> { Expense.count } do
      delete expense_path(other)
    end
    assert_response :not_found
  end

  test "index clamps an absurd year instead of crashing" do
    get expenses_path(year: "999999999999")

    assert_response :success
  end
end
