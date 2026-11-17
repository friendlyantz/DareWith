require "rails_helper"

RSpec.describe ChallengeParticipant::Streak do
  let(:today) { Date.new(2026, 11, 17) }

  let(:daily) { build(:challenge_story, start: today - 30.days, finish: today + 30.days).goal }

  def streak(*days_ago)
    described_class.new(days_ago.map { today - it }, daily)
  end

  describe "#current" do
    it "counts a day with several check-ins once" do
      expect(streak(0, 0, 1).current(today)).to eq 2
    end

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

    it "still counts missed days a freeze covered" do
      expect(streak(0, *3..9).comeback?).to be true
    end
  end

  describe "freezes" do
    it "earns one after 7 days in a row" do
      expect(streak(*0..6).freezes(today)).to eq 1
    end

    it "earns none before 7 days" do
      expect(streak(*0..5).freezes(today)).to eq 0
    end

    it "holds at most two" do
      expect(streak(*0..27).freezes(today)).to eq 2
    end

    it "covers a missed day without adding it to the streak" do
      streak = streak(0, *2..8)

      expect(streak.current(today)).to eq 8
      expect(streak).to be_frozen_yesterday(today)
    end

    it "keeps the streak alive while yesterday is covered" do
      streak = streak(*2..8)

      expect(streak.current(today)).to eq 7
      expect(streak.freezes(today)).to eq 0
      expect(streak).to be_frozen_yesterday(today)
    end

    it "covers two missed days in a row with two freezes" do
      expect(streak(0, *3..16).current(today)).to eq 15
    end

    it "breaks when the misses outnumber the freezes" do
      expect(streak(0, *3..9).current(today)).to eq 1
    end

    it "is gone once the streak breaks" do
      expect(streak(*3..9).freezes(today)).to eq 0
    end

    it "counts covered streaks toward the longest" do
      expect(streak(*10..20, *22..30).longest).to eq 20
    end

    it "notices a freeze earned today" do
      expect(streak(*0..6)).to be_freeze_earned_today(today)
      expect(streak(*0..7)).not_to be_freeze_earned_today(today)
    end

    it "counts the days to the next freeze" do
      expect(streak(0, 1, 2).days_to_next_freeze(today)).to eq 4
      expect(streak(*0..9).days_to_next_freeze(today)).to eq 4
    end

    it "has no next freeze while holding two" do
      expect(streak(*0..13).days_to_next_freeze(today)).to be_nil
    end

    it "lists the missed days a freeze covered" do
      expect(streak(0, *2..8).frozen_indexes(today)).to eq [29]
    end

    it "uses the freezes on the first days of a gap too long to save the streak" do
      expect(streak(0, *4..10).frozen_indexes(today)).to eq [27]
    end

    it "isn't frozen yesterday when yesterday was kept or the streak starts today" do
      expect(streak(*0..7)).not_to be_frozen_yesterday(today)
      expect(streak(0)).not_to be_frozen_yesterday(today)
    end
  end
end

RSpec.describe ChallengeParticipant::Streak, "weekly" do
  let(:start) { Date.new(2026, 11, 2) }
  let(:goal) { build(:challenge_story, :weekly, start:, finish: start + 55.days, times_per_period: 2).goal }

  def streak(*days_from_start)
    described_class.new(days_from_start.map { start + it }, goal)
  end

  it "counts weeks that hit the weekly count" do
    expect(streak(0, 3, 7, 9, 14).current(start + 15.days)).to eq 2
  end

  it "stays alive while this week is still open" do
    expect(streak(0, 3, 7, 9).current(start + 20.days)).to eq 2
  end

  it "breaks after a week that missed the count" do
    expect(streak(0, 3, 7).current(start + 15.days)).to eq 0
  end

  it "never earns freezes" do
    weeks = (0..7).flat_map { [it * 7, it * 7 + 1] }

    expect(streak(*weeks).freezes(start + 56.days)).to eq 0
    expect(streak(*weeks).days_to_next_freeze(start + 56.days)).to be_nil
  end
end
