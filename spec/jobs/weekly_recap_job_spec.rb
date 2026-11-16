require "rails_helper"

RSpec.describe WeeklyRecapJob, type: :job do
  it "sends recaps to users with a device on Sunday evening" do
    story = create(:challenge_story, start: Date.new(2026, 11, 10), finish: Date.new(2026, 11, 30))
    with_device = create(:user, time_zone: "UTC")
    create(:web_push_notification, user: with_device)
    create(:challenge_participant, user: with_device, challenge_story: story)
    create(:challenge_participant, user: create(:user, time_zone: "UTC"), challenge_story: story)

    travel_to(Time.utc(2026, 11, 22, 18, 0)) do
      expect { described_class.perform_now }.to have_enqueued_job(PushNotificationJob).exactly(:once)
    end
  end
end
