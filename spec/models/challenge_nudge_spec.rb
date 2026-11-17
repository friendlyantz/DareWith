require "rails_helper"

RSpec.describe ChallengeNudge do
  let(:story) { create(:challenge_story, title: "Push-ups") }
  let(:anna) { create(:challenge_participant, challenge_story: story, user: create(:user, username: "anna")) }
  let(:ben) { create(:challenge_participant, challenge_story: story) }

  before { create(:challenge_check_in, challenge_participant: anna) }

  def nudge(sender: anna, receiver: ben)
    ChallengeNudge.new(sender:, receiver:)
  end

  it "lets a friend who checked in nudge someone who hasn't" do
    expect(nudge).to be_valid
  end

  it "needs the sender to have checked in today" do
    expect(nudge(sender: ben, receiver: anna)).not_to be_valid
  end

  it "doesn't nudge someone who already checked in" do
    create(:challenge_check_in, challenge_participant: ben)

    expect(nudge).not_to be_valid
  end

  it "doesn't nudge someone whose week is already done" do
    weekly = create(:challenge_story, :weekly, times_per_period: 1)
    sender = create(:challenge_participant, challenge_story: weekly)
    receiver = create(:challenge_participant, challenge_story: weekly)
    create(:challenge_check_in, challenge_participant: sender)
    create(:challenge_check_in, challenge_participant: receiver).update_column(:checked_in_on, Time.zone.yesterday)
    weekly.update_column(:start, Time.zone.yesterday)

    expect(nudge(sender:, receiver:)).not_to be_valid
  end

  it "doesn't nudge people in another challenge" do
    expect(nudge(receiver: create(:challenge_participant))).not_to be_valid
  end

  it "doesn't nudge people who left" do
    ben.leave!

    expect(nudge).not_to be_valid
  end

  it "doesn't nudge once check-ins are closed" do
    story.update_columns(start: Time.zone.today - 10, finish: Time.zone.today - 3)

    expect(nudge).not_to be_valid
  end

  it "allows one nudge per friend per day" do
    nudge.save!

    expect(nudge).not_to be_valid
  end

  describe "#deliver" do
    let!(:device) { create(:web_push_notification, user: ben.user) }

    it "pushes to the friend" do
      expect { nudge.tap(&:save!).deliver }
        .to have_enqueued_job(PushNotificationJob)
        .with(device, title: "anna nudged you 👋", body: "Your turn on Push-ups. anna already checked in today.", path: "/challenge_stories/#{story.id}")
    end

    it "pushes only the first nudge someone gets in a challenge each day" do
      nudge.tap(&:save!).deliver
      cara = create(:challenge_participant, challenge_story: story)
      create(:challenge_check_in, challenge_participant: cara)

      expect { nudge(sender: cara).tap(&:save!).deliver }.not_to have_enqueued_job(PushNotificationJob)
    end
  end
end
