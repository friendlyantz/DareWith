require "rails_helper"

RSpec.describe "ChallengeFinales", type: :request do
  describe "GET /challenge_stories/:id/finale" do
    it "sends you back to the challenge while it's still running" do
      story = create(:challenge_story)

      get challenge_story_challenge_finale_path(story)

      expect(response).to redirect_to(challenge_story_path(story))
    end

    it "shows the slides once time's up" do
      story = create(:challenge_story, :finished, title: "Morning run")
      anna = create(:challenge_participant, challenge_story: story, user: create(:user, username: "anna"))
      [0, 1, 2].each { create(:challenge_check_in, challenge_participant: anna, checked_in_on: story.start + it) }

      get challenge_story_challenge_finale_path(story)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Morning run", "That's a wrap", "3 of 8 days", "Longest streak")
    end

    it "offers the participant their finish card" do
      user = create(:user)
      story = create(:challenge_story, :finished, :with_participant, participant_user: user)
      sign_in_as(user)

      get challenge_story_challenge_finale_path(story)

      expect(response.body).to include("Share my finish", "You did it")
    end
  end
end
