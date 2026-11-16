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
end
