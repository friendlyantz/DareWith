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
    # The page didn't reload, so its progress cards were swapped for ones with this check-in
    expect(page).to have_css("#header_challenge_story_#{challenge.id} [data-share-card-headline-value='1']")
    expect(page).to have_css("#invite_card_challenge_story_#{challenge.id} [data-share-card-headline-value='1']")
  end

  scenario "participant checks in from Today and stays there" do
    visit today_path

    click_on "Check in"

    within "dialog" do
      fill_in "message", with: "From Today"
      click_on "submit"
      click_on "Done"
    end

    expect(page).to have_current_path(today_path)
    expect(page).to have_no_css("dialog[open]")
  end

  scenario "participant checks in from the form opened as its own page" do
    visit new_challenge_story_challenge_check_in_path(challenge)

    fill_in "message", with: "Opened in a new tab"
    click_on "submit"
    click_on "Done"

    expect(page).to have_current_path(challenge_story_path(challenge))
    expect(page).to have_content("You checked in today")
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

  scenario "friend doubts a check-in and withdraws the doubt" do
    friend = create(:challenge_participant, challenge_story: challenge)
    create(:challenge_check_in, challenge_participant: friend, message: "Did my run")
    create(:challenge_check_in, challenge_participant: participant, message: "My own")

    show_page.load

    within("article", text: "My own") { expect(page).to have_no_content("Doubt it") }
    within("article", text: "Did my run") do
      find("summary", text: "Doubt it").click
      fill_in "challenge_check_in_doubt[note]", with: "That's yesterday's photo"
      click_on "Doubt"
    end

    within("article", text: "Did my run") do
      expect(page).to have_content("Doubted by #{user.username}")
      expect(page).to have_content("That's yesterday's photo")
      click_on "Withdraw doubt"
    end

    within("article", text: "Did my run") do
      expect(page).to have_no_content("Doubted by")
      expect(page).to have_content("Doubt it")
    end
  end

  scenario "friend doubts a check-in from the feed and stays on it" do
    friend = create(:challenge_participant, challenge_story: challenge)
    create(:challenge_check_in, challenge_participant: friend, message: "Did my run")
    create(:challenge_check_in, challenge_participant: participant, message: "My own")

    visit challenge_check_ins_path
    within("article", text: "My own") { expect(page).to have_css("button[aria-label='Delete check-in']") }

    within("article", text: "Did my run") do
      find("summary", text: "Doubt it").click
      click_on "Doubt"
    end

    expect(page).to have_current_path(challenge_check_ins_path)
    within("article", text: "Did my run") { expect(page).to have_content("Doubted by #{user.username}") }
    within("article", text: "My own") { expect(page).to have_css("button[aria-label='Delete check-in']") }
  end

  scenario "opening an alert about a check-in shows the Check-ins tab, even when another tab was last open" do
    check_in = create(:challenge_check_in, challenge_participant: participant, message: "Linked check-in")
    create(:notification, user:, title: "Sam doubts your check-in", path: challenge_story_path(challenge, anchor: "challenge_check_in_#{check_in.id}"))
    show_page.load
    find("#challenge_tab_leaderboard").click
    expect(page).to have_no_content("Linked check-in")

    visit notifications_path
    click_on "Sam doubts your check-in"

    expect(page).to have_content("Linked check-in")
  end
end
