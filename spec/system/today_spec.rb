require "system_helper"

RSpec.describe "Today", type: :system do
  let(:user) { create(:user) }
  let(:challenge) { create(:challenge_story, title: "Morning run") }
  let!(:participant) { create(:challenge_participant, user: user, challenge_story: challenge) }

  before do
    sign_in_as(user)
  end

  scenario "participant checks in from the sheet" do
    visit today_path

    expect(page).to have_content("0 of 1 done today")

    click_on "Check in"

    within "dialog" do
      fill_in "message", with: "5 km before breakfast"
      click_on "submit"
    end

    expect(page).to have_content("1 of 1 done today")
    expect(page).to have_no_link("Check in")
    expect(participant.challenge_check_ins.last.message).to eq("5 km before breakfast")
  end
end
