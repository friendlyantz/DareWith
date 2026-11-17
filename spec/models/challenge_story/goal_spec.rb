require "rails_helper"

RSpec.describe ChallengeStory::Goal do
  describe "#summary" do
    it "is empty for a plain daily challenge" do
      expect(build(:challenge_story).goal.summary).to be_nil
    end

    it "describes what is counted" do
      expect(build(:challenge_story, unit: :km).goal.summary).to eq "counting km"
    end

    it "describes a target each time" do
      expect(build(:challenge_story, unit: :reps, target_amount: 50, target_scope: :each_time).goal.summary).to eq "50 reps each time"
    end

    it "describes a total target" do
      expect(build(:challenge_story, unit: :km, target_amount: 100, target_scope: :total).goal.summary).to eq "100 km each by the end"
    end

    it "describes a weekly cadence" do
      story = build(:challenge_story, cadence: :weekly, times_per_period: 3, unit: :km, target_amount: 5.5, target_scope: :each_time)

      expect(story.goal.summary).to eq "3× a week · 5.5 km each time"
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
  end

  it "keeps a week once it has enough check-ins" do
    dates = [start, start + 2.days, start + 4.days, start + 8.days]

    expect(weekly.kept_period_indexes(dates)).to eq [0]
  end

  it "counts the grace day after the end toward the last week" do
    last_week = (start + 21.days..start + 22.days).to_a

    expect(weekly.kept_period_indexes(last_week + [start + 28.days])).to eq [3]
  end
end
