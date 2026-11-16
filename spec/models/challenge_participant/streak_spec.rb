require "rails_helper"

RSpec.describe ChallengeParticipant::Streak do
  let(:today) { Date.new(2026, 11, 17) }

  def streak(*days_ago)
    described_class.new(days_ago.map { today - it })
  end

  describe "#current" do
    it "counts consecutive days up to today" do
      expect(streak(0, 1, 2, 4).current(today)).to eq 3
    end

    it "is still alive when the last check-in was yesterday" do
      expect(streak(1, 2).current(today)).to eq 2
    end

    it "is broken after a missed day" do
      expect(streak(2, 3).current(today)).to eq 0
    end

    it "is zero without check-ins" do
      expect(streak.current(today)).to eq 0
    end
  end

  describe "#longest" do
    it "finds the longest run" do
      expect(streak(0, 5, 6, 7, 8, 10).longest).to eq 4
    end
  end

  describe "#comeback?" do
    it "is true after missing two days" do
      expect(streak(0, 3).comeback?).to be true
    end

    it "is false after missing one day" do
      expect(streak(0, 2).comeback?).to be false
    end
  end
end
