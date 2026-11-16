require "rails_helper"

RSpec.describe "Admin dashboard", type: :request do
  describe "GET /admin" do
    it "is not found for visitors" do
      get admin_root_path

      expect(response).to have_http_status(:not_found)
    end

    it "is not found for other users" do
      sign_in_as(create(:user))

      get admin_root_path

      expect(response).to have_http_status(:not_found)
    end

    context "when signed in as the admin" do
      let(:admin) { create(:user, username: "friendlyantz") }

      before { sign_in_as(admin) }

      it "shows users, push devices and running challenges" do
        story = create(:challenge_story, title: "Morning run")
        participant = create(:challenge_participant, user: create(:user, username: "maria"), challenge_story: story)
        create(:challenge_check_in, challenge_participant: participant)
        create(:web_push_notification, user: participant.user, user_agent: "Mozilla/5.0 (iPhone) Safari")

        get admin_root_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include("Morning run")
        expect(response.body).to include("maria")
        expect(response.body).to include("Safari on iPhone · 1")
        expect(response.body).to include("1 of 2 users have push on")
        expect(response.body).to include("Job stats show in production only")
      end
    end
  end

  describe "the Me page" do
    it "links to the dashboard for the admin only" do
      sign_in_as(create(:user, username: "friendlyantz"))
      get profile_path
      expect(response.body).to include(admin_root_path)

      sign_in_as(create(:user))
      get profile_path
      expect(response.body).not_to include(admin_root_path)
    end
  end
end
