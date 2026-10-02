require "application_system_test_case"

# Smoke test for the real Stimulus wiring: the pure arithmetic is unit-tested
# in test/javascript, but only a browser proves the controls are connected.
class TimeEntryTimerTest < ApplicationSystemTestCase
  test "the stopwatch starts, pauses for a break, resumes and stops" do
    sign_in

    visit time_entries_path

    click_button "Start timer"
    assert_button "Stop timer"
    assert_button "Take break"

    click_button "Take break"
    assert_button "Resume"
    assert_text "On break — the clock is paused."

    click_button "Resume"
    assert_button "Take break"

    click_button "Stop timer"
    assert_button "Start timer"
    # The timer wrote a rounded decimal into the hours field.
    assert_match(/\A\d+\.\d{2}\z/, find("[data-timer-target='hours']").value)
  end

  private
    def sign_in
      visit new_session_path
      fill_in "Email", with: "blake@example.com"
      fill_in "Password", with: "password"
      click_button "Sign in"
      assert_text "Dashboard"
    end
end
