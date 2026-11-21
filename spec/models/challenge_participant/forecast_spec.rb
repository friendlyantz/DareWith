require "rails_helper"

RSpec.describe ChallengeParticipant::Forecast do
  let(:start) { Date.new(2026, 11, 1) }
  let(:story) { create(:challenge_story, start:, finish: start + 29.days, unit: :km, target_amount: 100, target_scope: :total) }
  let(:participant) { create(:challenge_participant, challenge_story: story) }

  def run(km, on:)
    create(:challenge_check_in, challenge_participant: participant, amount: km, checked_in_on: on)
  end

  def forecast(today)
    described_class.new(participant.reload, today)
  end

  it "finds the day the average reaches the target" do
    run(10, on: start)
    run(10, on: start + 1.day)

    expect(forecast(start + 3.days).reach_on).to eq start + 19.days
  end

  it "projects the total when the target is out of reach" do
    run(20, on: start)

    result = forecast(start + 9.days)
    expect(result.reach_on).to be_nil
    expect(result.projected_total).to eq 60
  end

  it "adds up several check-ins on one day" do
    run(30, on: start)
    run(30, on: start)

    expect(forecast(start + 1.day).reach_on).to eq start + 3.days
  end

  it "knows when the target is reached" do
    run(100, on: start)

    expect(forecast(start + 1.day)).to be_reached
  end

  it "is only for running challenges with a total target and some progress" do
    expect(forecast(start + 1.day)).not_to be_available
    run(5, on: start)
    expect(forecast(start + 1.day)).to be_available
    expect(forecast(start + 30.days)).not_to be_available
    story.update_columns(target_scope: :each_period)
    expect(forecast(start + 1.day)).not_to be_available
  end
end
