require "rails_helper"

RSpec.describe ChallengeStoriesHelper, "#starts_in", type: :helper do
  def starts_in_days(days)
    helper.starts_in(build(:challenge_story, start: Time.zone.today + days, finish: Time.zone.today + days + 7))
  end

  it "says tomorrow for the day before" do
    expect(starts_in_days(1)).to eq "Starts tomorrow"
  end

  it "counts the days further out" do
    expect(starts_in_days(3)).to eq "Starts in 3 days"
  end
end
