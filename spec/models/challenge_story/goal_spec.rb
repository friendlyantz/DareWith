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
      expect(build(:challenge_story, unit: :km, target_amount: 100, target_scope: :total).goal.summary).to eq "100 km in total"
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
  end
end
