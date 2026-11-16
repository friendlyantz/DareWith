require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /me" do
    it "asks visitors to sign in" do
      get profile_path

      expect(response).to redirect_to(new_webauthn_session_path)
    end

    context "when signed in" do
      let(:user) { create(:user, username: "anton") }

      before { sign_in_as(user) }

      it "shows the user and their finished challenges" do
        create(:challenge_participant, user: user, challenge_story: create(:challenge_story, :completed, title: "Old one"))
        create(:challenge_participant, user: user, challenge_story: create(:challenge_story, title: "Running one"))

        get profile_path

        expect(response.body).to include("anton")
        expect(response.body).to include("1 active challenge")
        expect(response.body).to include("Old one")
        expect(response.body).not_to include("Running one")
      end
    end
  end
end
