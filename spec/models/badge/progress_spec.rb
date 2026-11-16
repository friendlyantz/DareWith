require "rails_helper"

RSpec.describe Badge::Progress do
  let(:user) { create(:user) }
  let(:participant) { create(:challenge_participant, user:) }

  def next_up
    described_class.new(user).next_up(limit: 3).map { [it.kind, it.current, it.goal] }
  end

  it "starts with the first check-in" do
    expect(next_up).to include(["first_check_in", 0, 1])
  end

  it "counts the current streak towards the next streak badge" do
    create(:badge, user:)
    create(:badge, user:, kind: :three_day_streak)
    create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.today)
    create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.yesterday)

    expect(next_up).to include(["week_streak", 2, 7])
    expect(next_up.map(&:first)).not_to include("first_check_in")
  end

  it "counts likes on friends' check-ins towards cheerleader" do
    friend_check_in = create(:challenge_check_in)
    create(:challenge_check_in_like, user:, challenge_check_in: friend_check_in)

    expect(next_up).to include(["cheerleader", 1, 10])
  end

  it "puts the closest badge first" do
    create(:challenge_check_in, challenge_participant: participant)

    expect(described_class.new(user, earned_kinds: []).next_up.first.kind).to eq "three_day_streak"
  end
end
