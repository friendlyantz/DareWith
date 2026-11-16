require "rails_helper"

RSpec.describe BadgeAwardJob, type: :job do
  let(:user) { create(:user) }
  let!(:device) { create(:web_push_notification, user:) }

  before { create(:challenge_check_in, challenge_participant: create(:challenge_participant, user:)) }

  it "tells the user about a new badge" do
    expect { described_class.perform_now(user) }
      .to have_enqueued_job(PushNotificationJob)
      .with(device, title: "👟 New badge: First step", body: "Checked in for the first time", path: "/me")
  end

  it "awards quietly when asked to" do
    expect { described_class.perform_now(user, announce: false) }.not_to have_enqueued_job(PushNotificationJob)
    expect(user.badges.first_check_in).to exist
  end
end
