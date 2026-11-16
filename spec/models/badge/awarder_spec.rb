require "rails_helper"

RSpec.describe Badge::Awarder do
  let(:user) { create(:user) }
  let(:challenge_story) { create(:challenge_story, start: Time.zone.today - 9.days, finish: Time.zone.today) }
  let(:participant) { create(:challenge_participant, user:, challenge_story:) }

  def check_in_days_ago(*days)
    days.each { create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.today - it) }
  end

  def award
    described_class.new(user).award.map(&:kind)
  end

  it "awards nothing without activity" do
    expect(award).to be_empty
  end

  it "awards the first check-in and streak badges for the challenge" do
    check_in_days_ago(*0..6)

    expect(award).to contain_exactly("first_check_in", "three_day_streak", "week_streak")
    expect(user.badges.week_streak.sole.challenge_story).to eq challenge_story
  end

  it "doesn't award the same badge twice" do
    check_in_days_ago(0, 1, 2)
    award

    expect(award).to be_empty
    expect(user.reload.badges_count).to eq 2
  end

  it "awards streak badges again in another challenge" do
    check_in_days_ago(0, 1, 2)
    other = create(:challenge_participant, user:)
    3.times { create(:challenge_check_in, challenge_participant: other, checked_in_on: Time.zone.today - it) }

    expect(award.tally).to eq("first_check_in" => 1, "three_day_streak" => 2)
  end

  it "awards a comeback after missing a few days" do
    check_in_days_ago(0, 5)

    expect(award).to include("comeback")
  end

  context "when the challenge is completed" do
    before { challenge_story.update!(completed: true) }

    it "awards finisher for 80% of the days" do
      check_in_days_ago(0, 1, 2, 3, 5, 6, 7, 9)

      expect(award).to include("finisher")
      expect(award).not_to include("flawless")
    end

    it "awards flawless for every day" do
      check_in_days_ago(*0..9)

      expect(award).to include("finisher", "flawless")
    end

    it "skips participants who left" do
      check_in_days_ago(*0..9)
      participant.leave!

      expect(award).to contain_exactly("first_check_in")
    end
  end

  it "awards cheerleader for liking ten check-ins from friends" do
    friend = create(:challenge_participant, challenge_story:)
    own_check_in = create(:challenge_check_in, challenge_participant: participant)
    create(:challenge_check_in_like, user:, challenge_check_in: own_check_in)
    9.times { create(:challenge_check_in_like, user:, challenge_check_in: create(:challenge_check_in, challenge_participant: friend, checked_in_on: Time.zone.today - it)) }

    expect(award).not_to include("cheerleader")

    create(:challenge_check_in_like, user:, challenge_check_in: create(:challenge_check_in, challenge_participant: friend, checked_in_on: Time.zone.today - 9))

    expect(award).to include("cheerleader")
  end

  it "awards good for it when a pledged reward is received" do
    friend = create(:challenge_participant, challenge_story:)
    reward = create(:challenge_reward, giver: participant, receiver: friend)

    expect(award).to be_empty

    reward.fulfill!

    expect(award).to eq ["good_for_it"]
  end
end
