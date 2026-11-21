require "rails_helper"

RSpec.describe ChallengeStory::Goal do
  describe "#summary" do
    it "is empty for a plain daily challenge" do
      expect(build(:challenge_story).goal.summary).to be_nil
    end

    it "describes what is counted" do
      expect(build(:challenge_story, unit: :km).goal.summary).to eq "counting km"
    end

    it "describes a target each day" do
      expect(build(:challenge_story, unit: :reps, target_amount: 50, target_scope: :each_period).goal.summary).to eq "50 reps a day"
    end

    it "describes a total target" do
      expect(build(:challenge_story, unit: :km, target_amount: 100, target_scope: :total).goal.summary).to eq "100 km each by the end"
    end

    it "describes a weekly cadence" do
      story = build(:challenge_story, cadence: :weekly, times_per_period: 3, unit: :km, target_amount: 5.5, target_scope: :each_period)

      expect(story.goal.summary).to eq "3× a week · 5.5 km a week"
    end
  end

  describe "#format_amount" do
    let(:goal) { build(:challenge_story, unit: :reps).goal }

    it "drops trailing zeros" do
      expect(goal.format_amount(BigDecimal("50.00"))).to eq "50 reps"
      expect(goal.format_amount(BigDecimal("2.50"))).to eq "2.5 reps"
    end

    it "uses the singular for one" do
      expect(goal.format_amount(1)).to eq "1 rep"
    end

    it "never pluralises km" do
      expect(build(:challenge_story, unit: :km).goal.format_amount(12)).to eq "12 km"
    end

    it "counts hours, singular for one" do
      goal = build(:challenge_story, unit: :hours).goal

      expect(goal.format_amount(1)).to eq "1 hour"
      expect(goal.format_amount(BigDecimal("1.50"))).to eq "1.5 hours"
    end
  end

  describe "#whole_numbers?" do
    it "takes decimals for hours and km, but whole numbers for the rest" do
      expect(build(:challenge_story, unit: :hours).goal).not_to be_whole_numbers
      expect(build(:challenge_story, unit: :km).goal).not_to be_whole_numbers
      expect(build(:challenge_story, unit: :minutes).goal).to be_whole_numbers
    end
  end
end

RSpec.describe ChallengeStory::Goal, "periods" do
  let(:start) { Date.new(2026, 11, 18) } # a Wednesday
  let(:weekly) { build(:challenge_story, :weekly, start:, times_per_period: 3).goal }
  let(:daily) { build(:challenge_story, start:, finish: start + 9.days).goal }

  it "counts weeks from the start date, not from Monday" do
    expect(weekly.period_index(start + 6.days)).to eq 0
    expect(weekly.period_index(start + 7.days)).to eq 1
    expect(weekly.progress_label(start + 7.days)).to eq "Week 2 of 4"
    expect(daily.progress_label(start + 2.days)).to eq "Day 3 of 10"
  end

  it "knows how many days are left in the week" do
    expect(weekly.days_left_in_period(start)).to eq 7
    expect(weekly.days_left_in_period(start + 6.days)).to eq 1
    expect(weekly.days_left_in_period(start + 28.days)).to eq 1
  end

  def check_ins(*days, amount: nil)
    days.map { ChallengeCheckIn.new(checked_in_on: start + it, amount:) }
  end

  it "keeps a week once it has enough check-ins" do
    expect(weekly.kept_period_indexes(check_ins(0, 2, 4, 8))).to eq [0]
  end

  it "counts days, not check-ins" do
    expect(weekly.kept_period_indexes(check_ins(0, 0, 0))).to eq []
  end

  it "counts the grace day after the end toward the last week" do
    expect(weekly.kept_period_indexes(check_ins(21, 22, 28))).to eq [3]
  end

  context "with a target each week" do
    let(:weekly) { build(:challenge_story, :weekly, start:, times_per_period: 3, unit: :km, target_amount: 15, target_scope: :each_period).goal }

    it "keeps a week once its check-ins add up to the target" do
      expect(weekly.kept_period_indexes(check_ins(0, 0, 2, 4, amount: 4))).to eq [0]
    end

    it "misses a week short of the target, however many check-ins" do
      expect(weekly.kept_period_indexes(check_ins(0, 2, 4, amount: 4))).to eq []
    end

    it "misses a week that hit the target in too few days" do
      expect(weekly.kept_period_indexes(check_ins(0, 2, amount: 10))).to eq []
    end

    it "suggests an even share of the target" do
      expect(weekly.suggested_amount).to eq 5
    end
  end

  context "with a target each day" do
    let(:daily) { build(:challenge_story, start:, finish: start + 9.days, unit: :reps, target_amount: 50, target_scope: :each_period).goal }

    it "adds up a day's check-ins" do
      expect(daily.kept_period_indexes(check_ins(0, 0, 1, amount: 25))).to eq [0]
    end

    it "knows whether today is done" do
      expect(daily.period_kept?(check_ins(0, amount: 30), start)).to be false
      expect(daily.period_kept?(check_ins(0, 0, amount: 30), start)).to be true
    end

    it "describes what keeps a day" do
      expect(daily.kept_rule).to eq "Days with 50 reps"
    end
  end

  it "describes what keeps a week" do
    expect(weekly.kept_rule).to eq "Weeks with 3 check-ins"
    expect(daily.kept_rule).to eq "Days checked in"
  end
end
