require "rails_helper"

RSpec.describe User::WeeklyRecap do
  let(:sunday) { Date.new(2026, 11, 22) }
  let(:user) { create(:user) }
  let(:story) { create(:challenge_story, title: "Morning run", start: Date.new(2026, 11, 1), finish: Date.new(2026, 11, 30)) }
  let!(:participant) { create(:challenge_participant, user:, challenge_story: story) }

  def check_in(participant, *days)
    days.each { |day| create(:challenge_check_in, challenge_participant: participant, checked_in_on: day) }
  end

  subject(:recap) { described_class.new(user, sunday) }

  it "sums up the week with the running streak and friends' days" do
    check_in(participant, sunday - 8, sunday - 4, sunday - 2, sunday - 1, sunday)
    sam = create(:challenge_participant, challenge_story: story, user: create(:user, username: "Sam"))
    check_in(sam, *(sunday - 5..sunday))
    alex = create(:challenge_participant, challenge_story: story, user: create(:user, username: "Alex"))
    check_in(alex, sunday - 3)

    expect(recap.title).to eq("Your week: 4 of 7 days")
    expect(recap.body).to eq("🔥 3-day streak in Morning run. Sam 6 days and Alex 1 day")
  end

  it "only counts the days a challenge ran this week" do
    story.update!(start: sunday - 2)
    check_in(participant, sunday - 2)

    expect(recap.title).to eq("Your week: 1 of 3 days")
  end

  it "counts a day once across challenges" do
    other = create(:challenge_participant, user:, challenge_story: create(:challenge_story, start: sunday - 6, finish: sunday))
    check_in(participant, sunday)
    check_in(other, sunday)

    expect(recap.title).to eq("Your week: 1 of 7 days")
  end

  it "encourages a fresh start when the week was empty" do
    expect(recap.title).to eq("Your week: 0 of 7 days")
    expect(recap.body).to eq("A new week starts tomorrow")
  end

  it "leaves out friends who've left" do
    left = create(:challenge_participant, :inactive, challenge_story: story)
    check_in(left, sunday)

    expect(recap.body).to eq("A new week starts tomorrow")
  end

  it "skips challenges that ended before the week" do
    story.update!(finish: sunday - 7)

    expect(recap.any?).to be false
  end
end
