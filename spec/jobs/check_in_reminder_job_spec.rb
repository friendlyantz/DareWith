require "rails_helper"

RSpec.describe CheckInReminderJob, type: :job do
  it "reminds users with a device whose reminder hour has come" do
    due = create(:user, time_zone: "UTC", reminder_hour: 19)
    create(:web_push_notification, user: due)
    create(:challenge_participant, user: due, challenge_story: create(:challenge_story, start: Date.new(2026, 11, 10)))
    create(:user, time_zone: "UTC", reminder_hour: 19)

    travel_to(Time.utc(2026, 11, 16, 19, 0)) do
      expect { described_class.perform_now }.to have_enqueued_job(PushNotificationJob).exactly(:once)
    end
  end
end
