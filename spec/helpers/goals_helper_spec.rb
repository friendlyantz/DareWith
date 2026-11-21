require "rails_helper"

RSpec.describe GoalsHelper, "#freeze_progress_phrase", type: :helper do
  let(:today) { Time.zone.today }
  let(:story) { build(:challenge_story, start: today - 30.days, finish: today + 30.days) }

  def phrase(*days_ago)
    helper.freeze_progress_phrase(ChallengeParticipant::Streak.new(days_ago.map { ChallengeCheckIn.new(checked_in_on: today - it) }, story.goal))
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

RSpec.describe GoalsHelper, "weekly targets", type: :helper do
  let(:story) { create(:challenge_story, :weekly, start: Time.zone.today - 2.days, times_per_period: 3, unit: :km, target_amount: 15, target_scope: :each_period) }
  let(:participant) { create(:challenge_participant, challenge_story: story) }

  def check_in(amount, days_ago: 0)
    create(:challenge_check_in, challenge_participant: participant, challenge_story: story, amount:, checked_in_on: Time.zone.today - days_ago)
  end

  it "shows the distance alongside the check-ins" do
    check_in(4)

    expect(helper.week_progress(participant)).to eq "1 of 3 this week · 4 of 15 km · 5 days left"
  end

  it "asks for the distance once the days are done" do
    [2, 1, 0].each { check_in(4, days_ago: it) }

    expect(helper.check_in_button_label(participant)).to eq "Check in · 12 of 15 km"
  end
end
