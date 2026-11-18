require "rails_helper"

RSpec.describe ChallengeCompletionJob, type: :job do
  it "completes ended challenges, even with pledges still to settle, and leaves running ones" do
    ended = create(:challenge_story, :finished)
    create(:challenge_reward, challenge_story: ended,
      giver: create(:challenge_participant, challenge_story: ended),
      receiver: create(:challenge_participant, challenge_story: ended))
    running = create(:challenge_story)

    described_class.perform_now

    expect(ended.reload).to be_completed
    expect(running.reload).not_to be_completed
  end

  it "charges penalties for misses" do
    story = create(:challenge_story, :finished, penalty_mode: :per_miss, penalty: "a coffee")
    slacker = create(:challenge_participant, challenge_story: story)
    keen = create(:challenge_participant, challenge_story: story)
    (story.start..story.finish).each { create(:challenge_check_in, challenge_participant: keen, checked_in_on: it) }

    described_class.perform_now

    expect(story.challenge_rewards.penalty.sole).to have_attributes(giver: slacker, receiver: keen, description: "a coffee × 8")
  end

  it "waits until the grace day is over everywhere" do
    story = create(:challenge_story, start: Date.new(2026, 11, 10), finish: Date.new(2026, 11, 16), penalty_mode: :per_miss, penalty: "a coffee")
    create(:challenge_participant, challenge_story: story)
    create(:challenge_participant, challenge_story: story)

    travel_to(Time.utc(2026, 11, 18, 11, 0)) { described_class.perform_now }
    expect(story.challenge_rewards.penalty).to be_empty
    expect(story.reload).not_to be_completed

    travel_to(Time.utc(2026, 11, 18, 12, 0)) { described_class.perform_now }
    expect(story.challenge_rewards.penalty).to be_present
    expect(story.reload).to be_completed
  end
end
