require "system_helper"

RSpec.describe "Challenge nudges", type: :system do
  let(:anna) { create(:user, username: "anna") }
  let(:ben) { create(:user, username: "ben") }
  let(:challenge) { create(:challenge_story, title: "Push-ups") }
  let!(:annas_participation) { create(:challenge_participant, user: anna, challenge_story: challenge) }
  let!(:bens_participation) { create(:challenge_participant, user: ben, challenge_story: challenge) }

  scenario "a friend who checked in nudges someone who hasn't, and they see it on Today" do
    create(:challenge_check_in, challenge_participant: annas_participation)
    sign_in_as(anna)

    visit challenge_story_path(challenge)
    find("[aria-label=Leaderboard]").click
    click_on "Nudge"

    expect(page).to have_content("Nudged")
    expect(page).to have_no_button("Nudge")

    sign_in_as(ben)
    visit today_path

    expect(page).to have_content("anna nudged you")
  end
end
