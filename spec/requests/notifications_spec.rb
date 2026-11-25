require "rails_helper"

RSpec.describe "Notifications", type: :request do
  describe "GET /notifications" do
    it "asks visitors to sign up" do
      get notifications_path

      expect(response).to redirect_to(new_webauthn_registration_path)
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "lists the user's notifications newest first and marks them read" do
        create(:notification, user:, title: "Older", created_at: 1.hour.ago)
        create(:notification, user:, title: "Newer", body: "Your turn on Morning run")
        create(:notification, title: "Someone else's")

        get notifications_path

        expect(response.body).to include("Your turn on Morning run")
        expect(response.body.index("Newer")).to be < response.body.index("Older")
        expect(response.body).not_to include("Someone else&#39;s")
        expect(user.unread_notifications_count).to eq(0)
      end

      it "shows the unread count in the dock on other pages" do
        create_list(:notification, 3, user:)

        get today_path

        expect(response.body).to match(%r{id="notifications_badge".*?>3</span>}m)
      end
    end
  end
end
