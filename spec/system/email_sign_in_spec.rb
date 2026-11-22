require "system_helper"

# The email forms go through Turbo, which the Android app (Hotwire Native) needs
RSpec.describe "Signing in with an email code", type: :system do
  def ask_for_code(email)
    visit new_email_session_path
    fill_in "Email", with: email

    perform_enqueued_jobs do
      click_on "Continue with email"
      expect(page).to have_content("Check your email for a 6-digit code and a link.")
    end

    ActionMailer::Base.deliveries.last.subject[/\d{6}/]
  end

  scenario "someone with an account types the code and is signed in" do
    user = create(:user, email: "back@example.com")
    code = ask_for_code(user.email)

    fill_in "Code from the email", with: code
    click_on "Continue"

    expect(page).to have_current_path(new_challenge_story_path)
  end

  scenario "a wrong code says so and lets them try again" do
    create(:user, email: "back@example.com")
    code = ask_for_code("back@example.com")
    wrong = (code == "000000") ? "111111" : "000000"

    fill_in "Code from the email", with: wrong
    click_on "Continue"
    expect(page).to have_content("That code didn't work")

    fill_in "Code from the email", with: code
    click_on "Continue"
    expect(page).to have_current_path(new_challenge_story_path)
  end

  scenario "someone new types the code, picks a username and is signed in" do
    code = ask_for_code("new@example.com")

    fill_in "Code from the email", with: code
    click_on "Continue"
    fill_in "Username", with: "newbie"
    click_on "Create account"

    expect(page).to have_current_path(new_challenge_story_path)
    expect(User.find_by(username: "newbie").email).to eq("new@example.com")
  end
end
