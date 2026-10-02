require "test_helper"

class ExpenseTest < ActiveSupport::TestCase
  setup { @user = users(:blake) }

  test "is valid with the fixture data" do
    assert expenses(:software).valid?
  end

  test "requires a date, payee, category and amount" do
    expense = @user.expenses.new

    assert_not expense.valid?
    assert_includes expense.errors[:spent_on], "can't be blank"
    assert_includes expense.errors[:vendor], "can't be blank"
    assert_includes expense.errors[:category], "can't be blank"
    # The column defaults to zero, which fails the greater-than-zero check.
    assert_includes expense.errors[:amount], "must be greater than 0"
  end

  test "rejects a category outside the schedule" do
    expense = @user.expenses.new(
      spent_on: Date.current, vendor: "Marina", category: "Yacht", amount: 10
    )

    assert_not expense.valid?
    assert_includes expense.errors[:category], "is not included in the list"
  end

  test "requires a positive amount" do
    expense = @user.expenses.new(
      spent_on: Date.current, vendor: "Free", category: "Supplies", amount: 0
    )

    assert_not expense.valid?
    assert_includes expense.errors[:amount], "must be greater than 0"
  end

  test "client is optional" do
    expense = @user.expenses.new(
      spent_on: Date.current, vendor: "AWS", category: "Software and subscriptions", amount: 12
    )

    assert expense.valid?, expense.errors.full_messages.to_sentence
    assert_nil expense.client
  end

  test "for_year scopes to the calendar year" do
    this_year = @user.expenses.for_year(Date.current.year)

    assert_includes this_year, expenses(:software)
    assert_not_includes this_year, expenses(:other_user_expense)
    assert_empty @user.expenses.for_year(Date.current.year - 5)
  end

  test "rejects a client owned by another user" do
    expense = @user.expenses.new(
      spent_on: Date.current, vendor: "Sketchy", category: "Other", amount: 10,
      client: clients(:rival)
    )

    assert_not expense.valid?
    assert_includes expense.errors[:client], "is not yours"
  end
end
