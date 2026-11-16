require "rails_helper"

RSpec.describe WebPushNotification, type: :model do
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
