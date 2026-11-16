require "rails_helper"

RSpec.describe WebPushNotification, type: :model do
  describe ".describe_device" do
    it "names the browser and platform" do
      expect(described_class.describe_device("Mozilla/5.0 (Android 14; Mobile; rv:133.0) Gecko/133.0 Firefox/133.0")).to eq("Firefox on Android")
      expect(described_class.describe_device("Mozilla/5.0 (Linux; Android 14; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Mobile Safari/537.36")).to eq("Chrome on Android")
      expect(described_class.describe_device("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.0 Safari/605.1.15")).to eq("Safari on Mac")
    end
  end

  describe "#label" do
    it "prefers a name from the user agent over the stored one" do
      device = build(:web_push_notification, device_name: "Android Phone", user_agent: "Mozilla/5.0 (Android 14; Mobile; rv:133.0) Gecko/133.0 Firefox/133.0")

      expect(device.label).to eq("Firefox on Android")
    end

    it "falls back to the stored name" do
      expect(build(:web_push_notification, device_name: "Android Phone - ff mob", user_agent: nil).label).to eq("Android Phone - ff mob")
    end
  end

  describe "#send_notification" do
    let(:subscription) { create(:web_push_notification) }

    it "sends the payload with a VAPID subject" do
      allow(WebPush).to receive(:payload_send)

      subscription.send_notification(title: "maya checked in", body: "Leg day", path: "/challenge_stories/1")

      expect(WebPush).to have_received(:payload_send).with(hash_including(
        endpoint: subscription.endpoint,
        vapid: hash_including(subject: WebPushNotification::VAPID_SUBJECT)
      ))
    end

    it "removes the subscription when the push service says it expired" do
      allow(WebPush).to receive(:payload_send).and_raise(WebPush::ExpiredSubscription.new(double(body: ""), "push.example.com"))

      subscription.send_notification(title: "Hi")

      expect(WebPushNotification.exists?(subscription.id)).to be false
    end
  end
end
