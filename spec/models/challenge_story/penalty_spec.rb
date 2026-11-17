require "rails_helper"

RSpec.describe ChallengeStory::Penalty do
  let(:start) { Time.zone.today - 4.days }
  let(:story) { create(:challenge_story, start:, finish: start + 9.days, penalty_mode: :per_miss, penalty: "a coffee") }
  let(:anton) { create(:challenge_participant, challenge_story: story) }
  let(:bea) { create(:challenge_participant, challenge_story: story) }
  let(:penalty) { story.reload.penalty_rule }

  def check_in(participant, *days_from_start)
    days_from_start.each { create(:challenge_check_in, challenge_participant: participant, checked_in_on: story.start + it) }
  end

  describe "per miss" do
    it "counts the days that are over without a check-in, not today" do
      check_in(anton, 0, 2)
      check_in(bea, 0, 1, 2, 3)

      expect(penalty.owed_by(anton)).to eq "a coffee × 2"
      expect(penalty.owed_by(bea)).to be_nil
    end

    it "says the penalty once for a single miss" do
      check_in(anton, 0, 1, 2)

      expect(penalty.owed_by(anton)).to eq "a coffee"
    end

    it "lets a streak freeze cover a miss" do
      story.update!(start: Time.zone.today - 9.days, finish: Time.zone.today + 5.days)
      check_in(anton, *0..6, 8)

      expect(story.reload.penalty_rule.times_owed_by(anton)).to eq 0
    end
  end

  describe "most misses" do
    before { story.update!(penalty_mode: :most_misses) }

    it "is owed once by whoever missed most" do
      check_in(anton, 0)
      check_in(bea, 0, 1, 2)

      expect(penalty.owed_by(anton)).to eq "a coffee"
      expect(penalty.owed_by(bea)).to be_nil
    end

    it "is owed by nobody when everyone ties" do
      check_in(anton, 0)
      check_in(bea, 1)

      expect(penalty.times_owed_by(anton)).to eq 0
      expect(penalty.times_owed_by(bea)).to eq 0
    end
  end

  describe "#charge!" do
    let(:start) { Time.zone.today - 12.days }

    it "turns each person's misses into a penalty pledge to every friend, once" do
      cleo = create(:challenge_participant, challenge_story: story)
      check_in(anton, *0..5)
      check_in(bea, *0..9)
      check_in(cleo, *0..9)

      expect(penalty.charge!.map { [it.giver, it.receiver, it.description] })
        .to contain_exactly([anton, bea, "a coffee × 4"], [anton, cleo, "a coffee × 4"])
      expect(story.reload.penalty_rule.charge!).to be_empty
      expect(story.challenge_rewards.penalty.pending.count).to eq 2
    end

    it "waits until check-ins close" do
      story.update!(finish: Time.zone.today)
      check_in(bea, 0)
      anton

      expect(story.reload.penalty_rule.charge!).to be_empty
    end

    it "sits beside a reward pledged between the same two people" do
      create(:challenge_reward, challenge_story: story, giver: anton, receiver: bea)
      check_in(bea, *0..9)

      expect(penalty.charge!.size).to eq 1
    end
  end
end
