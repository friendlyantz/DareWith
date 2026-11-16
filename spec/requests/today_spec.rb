require "rails_helper"

RSpec.describe "Today", type: :request do
  describe "GET /today" do
    it "asks visitors to sign in" do
      get today_path

      expect(response).to redirect_to(new_webauthn_session_path)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      let(:story) { create(:challenge_story, title: "Morning run") }
      let!(:participant) { create(:challenge_participant, user: user, challenge_story: story) }

      before { sign_in_as(user) }

      it "offers a check-in for each active challenge" do
        get today_path

        expect(response.body).to include("Morning run")
        expect(response.body).to include("0 of 1 done today")
        expect(response.body).to include(new_challenge_story_challenge_check_in_path(story))
      end

      it "shows challenges already checked in today as done" do
        create(:challenge_check_in, challenge_participant: participant)

        get today_path

        expect(response.body).to include("1 of 1 done today")
        expect(response.body).not_to include(new_challenge_story_challenge_check_in_path(story))
      end

      it "moves ended challenges to wrap up, outside the daily count" do
        ended = create(:challenge_story, :finished, title: "Old push-ups")
        create(:challenge_participant, user: user, challenge_story: ended)

        get today_path

        expect(response.body).to include("0 of 1 done today")
        expect(response.body).to include("Wrap up")
        expect(response.body).to include(challenge_story_challenge_rewards_path(ended))
      end

      it "leaves out challenges the user has left or that are completed" do
        participant.leave!
        create(:challenge_participant, user: user, challenge_story: create(:challenge_story, :completed, title: "Old one"))

        get today_path

        expect(response.body).not_to include("Morning run")
        expect(response.body).not_to include("Old one")
        expect(response.body).to include("No active challenges")
      end
    end
  end
end
