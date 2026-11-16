require "rails_helper"

RSpec.describe "WebPushNotifications", type: :request do
  let(:user) { create(:user) }
  let(:payload) do
    {endpoint: "https://push.example.com/device-1", keys: {auth: "new-auth", p256dh: "new-p256dh"}}.to_json
  end

  describe "DELETE /web_push_notifications/:id" do
    before { sign_in_as(user) }

    it "stops notifications to one of the user's devices" do
      device = create(:web_push_notification, user: user)

      delete web_push_notification_path(device)

      expect(WebPushNotification.exists?(device.id)).to be false
      expect(response).to redirect_to(profile_path)
    end

    it "can't remove someone else's device" do
      device = create(:web_push_notification)

      delete web_push_notification_path(device)

      expect(response).to have_http_status(:not_found)
      expect(WebPushNotification.exists?(device.id)).to be true
    end
  end

  describe "DELETE /web_push_notifications/unsubscribe" do
    before { sign_in_as(user) }

    it "removes the device with that endpoint" do
      device = create(:web_push_notification, user: user, endpoint: "https://push.example.com/device-1")

      delete unsubscribe_web_push_notifications_path, params: payload, headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:ok)
      expect(WebPushNotification.exists?(device.id)).to be false
    end
  end

  describe "POST /web_push_notifications" do
    it "rejects visitors" do
      post web_push_notifications_path, params: payload, headers: {"CONTENT_TYPE" => "application/json"}

      expect(response).to have_http_status(:unauthorized)
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "saves this device for the user" do
        post web_push_notifications_path, params: payload, headers: {"CONTENT_TYPE" => "application/json"}

        expect(response).to have_http_status(:created)
        expect(user.web_push_notifications.sole).to have_attributes(endpoint: "https://push.example.com/device-1", auth_key: "new-auth")
      end

      it "moves a shared device away from the previous user" do
        previous = create(:web_push_notification, endpoint: "https://push.example.com/device-1")

        post web_push_notifications_path, params: payload, headers: {"CONTENT_TYPE" => "application/json"}

        expect(WebPushNotification.exists?(previous.id)).to be false
        expect(user.web_push_notifications.count).to eq(1)
      end

      it "refreshes the keys of an existing device" do
        create(:web_push_notification, user: user, endpoint: "https://push.example.com/device-1", auth_key: "old")

        post web_push_notifications_path, params: payload, headers: {"CONTENT_TYPE" => "application/json"}

        expect(user.web_push_notifications.sole.auth_key).to eq("new-auth")
      end
    end
  end
end
