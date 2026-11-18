require "rails_helper"

RSpec.describe ChallengeRepeatJob, type: :job do
  def repeating_story(**attributes)
    create(:challenge_story, start: Time.zone.today - 6.days, finish: Time.zone.today, repeats: true, **attributes).tap do |story|
      participant = create(:challenge_participant, challenge_story: story)
      create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.today)
    end
  end

  it "lines up the next round on the last day of a repeating challenge, once" do
    story = repeating_story

    described_class.perform_now
    described_class.perform_now

    expect(story.reload.next_challenge_story).to have_attributes(start: Time.zone.today + 1.day, round: 2)
    expect(ChallengeStory.where(previous_challenge_story: story).count).to eq 1
  end

  it "leaves challenges that don't repeat, aren't on their last day, or that nobody checked in to" do
    not_repeating = repeating_story(repeats: false)
    not_over = repeating_story(finish: Time.zone.today + 1.day)
    abandoned = create(:challenge_story, :with_participant, start: Time.zone.today - 6.days, finish: Time.zone.today, repeats: true)

    described_class.perform_now

    expect([not_repeating, not_over, abandoned].map { it.reload.next_challenge_story }).to all(be_nil)
  end

  it "leaves a round someone already started by hand" do
    story = repeating_story
    story.next_round.save!

    expect { described_class.perform_now }.not_to change(ChallengeStory, :count)
  end
end
