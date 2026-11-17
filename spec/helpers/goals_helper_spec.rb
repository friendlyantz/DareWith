require "rails_helper"

RSpec.describe GoalsHelper, "#freeze_progress_phrase", type: :helper do
  let(:today) { Time.zone.today }
  let(:story) { build(:challenge_story, start: today - 30.days, finish: today + 30.days) }

  def phrase(*days_ago)
    helper.freeze_progress_phrase(ChallengeParticipant::Streak.new(days_ago.map { today - it }, story.goal))
  end

  it "counts down to the first freeze" do
    expect(phrase(0)).to eq "6 more days to earn a streak freeze"
  end

  it "counts down to another while holding one" do
    expect(phrase(*0..7)).to eq "1 freeze · 6 more days to earn another"
  end

  it "says when both freezes are ready" do
    expect(phrase(*0..13)).to eq "2 freezes ready: miss a day and your streak keeps going"
  end

  it "says nothing for a weekly challenge" do
    story.assign_attributes(cadence: :weekly, times_per_period: 1)

    expect(phrase(0)).to be_nil
  end
end
