require "rails_helper"

RSpec.describe ChallengeStory::Repeat do
  let(:round_one) { create(:challenge_story, title: "Gym", start: Date.new(2026, 11, 12), finish: Date.new(2026, 11, 18), repeats: true) }
  let!(:keen) { create(:challenge_participant, challenge_story: round_one) }
  let!(:also_keen) { create(:challenge_participant, challenge_story: round_one) }
  let!(:gone) { create(:challenge_participant, :inactive, challenge_story: round_one) }

  around { |example| travel_to(Time.utc(2026, 11, 18, 1, 0)) { example.run } }

  it "starts the next round the day after this one ends, with the same length and the repeat kept on" do
    round_two = described_class.new(round_one).start!

    expect(round_two).to have_attributes(round: 2, start: Date.new(2026, 11, 19), finish: Date.new(2026, 11, 25), repeats: true, previous_challenge_story: round_one)
  end

  it "carries over everyone still in, and nobody who left" do
    round_two = described_class.new(round_one).start!

    expect(round_two.active_participants.map(&:user)).to contain_exactly(keen.user, also_keen.user)
  end

  it "tells everyone carried over that the round starts tomorrow" do
    create(:web_push_notification, user: keen.user)

    expect { described_class.new(round_one).start! }
      .to have_enqueued_job(PushNotificationJob).with(anything, hash_including(title: "Round 2 of Gym starts tomorrow"))
  end
end
