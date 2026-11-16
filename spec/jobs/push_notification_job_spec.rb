require "rails_helper"

RSpec.describe PushNotificationJob, type: :job do
  it "sends the notification to the subscription" do
    subscription = create(:web_push_notification)
    allow(subscription).to receive(:send_notification)

    described_class.perform_now(subscription, title: "maya checked in", body: "Leg day", path: "/today")

    expect(subscription).to have_received(:send_notification)
      .with(title: "maya checked in", body: "Leg day", path: "/today", icon: "/icons/icon-192.png")
  end
end
