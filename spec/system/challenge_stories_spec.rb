require "system_helper"

RSpec.describe "Challenge Stories", type: :system do
  let(:user) { create(:user) }
  let(:new_challenge_page) { prism.library.new_challenge_story }

  describe "creating a challenge" do
    before do
      sign_in_as(user)
    end

    scenario "user creates a new challenge successfully" do
      new_challenge_page.load

      expect(page).to have_content("New challenge")

      new_challenge_page.fill_form(
        title: "30 Day Fitness Challenge",
        description: "Exercise every day for 30 days",
        start_date: Time.zone.today,
        finish_date: Time.zone.today + 30.days
      )
      new_challenge_page.submit

      # Verify we're on the show page with the new challenge
      expect(page).to have_content("30 Day Fitness Challenge")
      expect(page).to have_content("Exercise every day for 30 days")
    end

    scenario "user sees validation error for invalid dates" do
      new_challenge_page.load

      new_challenge_page.fill_form(
        title: "Invalid Challenge",
        description: "This should fail",
        start_date: Time.zone.today,
        finish_date: Time.zone.today - 1.day
      )
      new_challenge_page.submit

      expect(page).to have_content("Finish cannot be earlier than the start date")
    end

    scenario "the unit and target are picked from the title as it's typed" do
      new_challenge_page.load

      new_challenge_page.fill_form(
        title: "Walk the dog 30+ minutes",
        start_date: Time.zone.today,
        finish_date: Time.zone.today + 29.days
      )

      expect(new_challenge_page.goal_summary).to have_text("Every day · 30 minutes a day · 30 days")
      new_challenge_page.submit

      expect(page).to have_content("Walk the dog 30+ minutes")
      expect(ChallengeStory.last).to have_attributes(unit: "minutes", target_amount: 30)
    end

    scenario "a unit picked by hand is kept while typing the title" do
      new_challenge_page.load

      new_challenge_page.unit_field.select("Reps")
      new_challenge_page.title_field.set("Squats, 5 km of them")

      expect(new_challenge_page.unit_field.value).to eq("reps")
      expect(new_challenge_page.target_amount_field.value).to eq("")
      expect(new_challenge_page.goal_summary).to have_text("Every day · counting reps")
    end

    scenario "the rules summary spells out the penalty and length" do
      new_challenge_page.load

      new_challenge_page.fill_form(title: "Gym", start_date: Time.zone.today, finish_date: Time.zone.today + 27.days)
      new_challenge_page.set_penalty("They owe everyone, every miss", "$5")
      check "Repeat automatically"

      expect(new_challenge_page.goal_summary).to have_text("Every day · just check in · Each miss: owe everyone $5 · 28 days · repeats")
      expect(page).to have_css("summary", text: "Each miss: owe everyone $5")
      new_challenge_page.submit

      expect(page).to have_content("Each miss: owe everyone $5")
      expect(ChallengeStory.last.description).to eq ""
    end

    scenario "a length chip sets the end date" do
      new_challenge_page.load

      expect(page).to have_checked_field("1 week", visible: :all)
      new_challenge_page.title_field.set("Stretch")
      new_challenge_page.choose_length("4 weeks")

      finish = Time.zone.today + 27.days
      expect(new_challenge_page.length_dates).to have_text("Starts today · ends #{finish.strftime("%a %-d %b")}")
      expect(new_challenge_page.goal_summary).to have_text("Every day · just check in · 28 days")
      new_challenge_page.submit

      expect(page).to have_content("Stretch")
      expect(ChallengeStory.last).to have_attributes(start: Time.zone.today, finish:)
    end

    scenario "going weekly moves 30 days to whole weeks" do
      new_challenge_page.load

      new_challenge_page.choose_length("30 days")
      new_challenge_page.cadence_field.select("Weekly")

      expect(page).to have_checked_field("4 weeks", visible: :all)
      expect(page).to have_no_css("label", text: "30 days")
      expect(new_challenge_page.goal_summary).to have_text("3× a week · just check in · 4 weeks")
    end
  end

  describe "viewing a challenge" do
    let!(:challenge) { create(:challenge_story, title: "Test Challenge") }
    let(:show_page) { prism.library.challenge_story(challenge) }

    before do
      sign_in_as(user)
    end

    scenario "user can view challenge details" do
      show_page.load

      expect(show_page).to be_displayed
      expect(page).to have_content("Test Challenge")
    end

    scenario "user can join a challenge" do
      show_page.load

      expect(show_page).to have_join_button

      show_page.join_button.click

      expect(page).to have_content("You've joined!")
    end
  end

  describe "challenge list" do
    let(:list_page) { prism.library.challenge_stories }

    before do
      create(:challenge_participant, user: user)
      sign_in_as(user)
    end

    scenario "user sees their active challenges" do
      list_page.load

      expect(page).to have_content("Challenges")
      expect(list_page).to have_challenge_cards
    end
  end
end
