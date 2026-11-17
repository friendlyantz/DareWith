require "rails_helper"

RSpec.describe ChallengeCompletionJob, type: :job do
  it "completes challenges that are ready and leaves the rest" do
    ready = create(:challenge_story, :finished)
    waiting = create(:challenge_story, :finished)
    create(:challenge_reward, challenge_story: waiting,
      giver: create(:challenge_participant, challenge_story: waiting),
      receiver: create(:challenge_participant, challenge_story: waiting))
    running = create(:challenge_story)

    described_class.perform_now

    expect(ready.reload).to be_completed
    expect(waiting.reload).not_to be_completed
    expect(running.reload).not_to be_completed
  end

  it "charges penalties for misses, so the challenge waits for them to be settled" do
    story = create(:challenge_story, :finished, penalty_mode: :per_miss, penalty: "a coffee")
    slacker = create(:challenge_participant, challenge_story: story)
    keen = create(:challenge_participant, challenge_story: story)
    (story.start..story.finish).each { create(:challenge_check_in, challenge_participant: keen, checked_in_on: it) }

    described_class.perform_now

    expect(story.challenge_rewards.penalty.sole).to have_attributes(giver: slacker, receiver: keen, description: "a coffee × 8")
    expect(story.reload).not_to be_completed
  end

  it "waits to charge penalties until the grace day is over everywhere" do
    story = create(:challenge_story, start: Date.new(2026, 11, 10), finish: Date.new(2026, 11, 16), penalty_mode: :per_miss, penalty: "a coffee")
    create(:challenge_participant, challenge_story: story)
    create(:challenge_participant, challenge_story: story)

    travel_to(Time.utc(2026, 11, 18, 0, 15)) { described_class.perform_now }
    expect(story.challenge_rewards.penalty).to be_empty

    travel_to(Time.utc(2026, 11, 19, 0, 15)) { described_class.perform_now }
    expect(story.challenge_rewards.penalty).to be_present
  end
end
