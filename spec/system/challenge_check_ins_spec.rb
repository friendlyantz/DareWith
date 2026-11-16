require "system_helper"

RSpec.describe "Challenge Check-ins", type: :system do
  let(:user) { create(:user) }
  let(:challenge) { create(:challenge_story) }
  let!(:participant) { create(:challenge_participant, user: user, challenge_story: challenge) }
  let(:show_page) { prism.library.challenge_story(challenge) }

  before do
    sign_in_as(user)
  end

  scenario "participant can check in with a message" do
    show_page.load

    expect(show_page).to be_displayed

    click_on "Check in"

    within "dialog" do
      fill_in "message", with: "Day 1: Completed my workout!"
      click_on "submit"

      expect(page).to have_content("NEW BADGE")
      expect(page).to have_content("First step")
      click_on "Done"
    end

    expect(page).to have_content("You checked in today")
    expect(page).to have_content("Day 1: Completed my workout!")
  end

  scenario "participant cannot check in twice in one day" do
    create(:challenge_check_in, challenge_participant: participant, challenge_story: challenge)

    show_page.load

    expect(page).to have_content("You checked in today")
    expect(page).to have_no_link("Check in")
  end

  describe "completed challenge" do
    let(:completed_challenge) { create(:challenge_story, :completed) }
    let!(:completed_participant) { create(:challenge_participant, user: user, challenge_story: completed_challenge) }
    let(:completed_show_page) { prism.library.challenge_story(completed_challenge) }

    scenario "participant cannot check in to completed challenge" do
      completed_show_page.load

      expect(page).to have_content("This challenge is over. No more check-ins are allowed.")
      expect(page).to have_no_link("Check in")
    end
  end
end
