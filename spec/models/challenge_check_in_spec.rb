require "rails_helper"

RSpec.describe ChallengeCheckIn, type: :model do
  describe "validations" do
    let(:challenge_participant) { create(:challenge_participant) }
    let(:story) { challenge_participant.challenge_story }

    it "allows several check-ins on the same day" do
      create(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)

      expect(create(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)).to be_persisted
    end
  end

  describe "#deletable_by?" do
    let(:check_in) { create(:challenge_check_in) }

    it "lets the author delete it on the day" do
      expect(check_in.deletable_by?(check_in.challenge_participant.user)).to be true
    end

    it "keeps it once the day is over" do
      check_in.update!(checked_in_on: Time.zone.yesterday)

      expect(check_in.deletable_by?(check_in.challenge_participant.user)).to be false
    end

    it "never lets someone else delete it" do
      expect(check_in.deletable_by?(create(:user))).to be false
      expect(check_in.deletable_by?(nil)).to be false
    end
  end

  describe "amount" do
    it "is needed when the challenge counts something" do
      participant = create(:challenge_participant, challenge_story: create(:challenge_story, unit: :reps))

      expect(build(:challenge_check_in, challenge_participant: participant)).not_to be_valid
      expect(build(:challenge_check_in, challenge_participant: participant, amount: 0)).not_to be_valid
      expect(build(:challenge_check_in, challenge_participant: participant, amount: 25)).to be_valid
    end

    it "is a whole number for reps but not for km" do
      reps = create(:challenge_participant, challenge_story: create(:challenge_story, unit: :reps))
      km = create(:challenge_participant, challenge_story: create(:challenge_story, unit: :km))

      expect(build(:challenge_check_in, challenge_participant: reps, amount: 2.5)).not_to be_valid
      expect(build(:challenge_check_in, challenge_participant: km, amount: 2.5)).to be_valid
    end

    it "keeps a saved whole-number amount valid" do
      reps = create(:challenge_participant, challenge_story: create(:challenge_story, unit: :reps))
      check_in = create(:challenge_check_in, challenge_participant: reps, amount: 25)

      expect(ChallengeCheckIn.find(check_in.id)).to be_valid
    end

    it "is ignored when the challenge only counts check-ins" do
      check_in = create(:challenge_check_in, amount: 25)

      expect(check_in.amount).to be_nil
    end
  end

  describe "broadcasting a new check-in" do
    let(:challenge_participant) { create(:challenge_participant) }
    let(:story) { challenge_participant.challenge_story }
    let(:fellow_participant) { create(:challenge_participant, challenge_story: story) }
    let(:outsider) { create(:user) }

    def feed_of(user)
      "#{user.to_gid_param}:challenge_check_ins_feed"
    end

    def create_check_in
      create(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)
    end

    it "prepends to the challenge story page" do
      expect { create_check_in }.to have_broadcasted_to(story.to_gid_param)
    end

    it "prepends to the feed of every participant" do
      expect { create_check_in }
        .to have_broadcasted_to(feed_of(challenge_participant.user))
        .and have_broadcasted_to(feed_of(fellow_participant.user))
    end

    it "does not reach the feed of users outside the challenge" do
      expect { create_check_in }.not_to have_broadcasted_to(feed_of(outsider))
    end
  end

  describe "#notify_other_participants" do
    let(:story) { create(:challenge_story, title: "Morning run") }
    let(:author) { create(:challenge_participant, challenge_story: story, user: create(:user, username: "maya")) }
    let(:friend) { create(:challenge_participant, challenge_story: story) }
    let!(:friend_device) { create(:web_push_notification, user: friend.user) }

    before { create(:web_push_notification, user: author.user) }

    it "notifies the other participants but not the author" do
      check_in = create(:challenge_check_in, challenge_participant: author, message: "5 km done")

      expect { check_in.notify_other_participants }
        .to have_enqueued_job(PushNotificationJob)
        .with(friend_device, title: "maya checked in", body: "Morning run: 5 km done", path: "/challenge_stories/#{story.id}")
        .exactly(:once)
    end

    it "only notifies for the first check-in of the day" do
      create(:challenge_check_in, challenge_participant: author)
      second = create(:challenge_check_in, challenge_participant: author)

      expect { second.notify_other_participants }.not_to have_enqueued_job(PushNotificationJob)
    end

    it "skips participants who left" do
      friend.leave!
      check_in = create(:challenge_check_in, challenge_participant: author)

      expect { check_in.notify_other_participants }.not_to have_enqueued_job(PushNotificationJob)
    end
  end

  describe "#liked_by?" do
    let(:check_in) { create(:challenge_check_in) }
    let(:user) { create(:user) }

    it "returns false when user is nil" do
      expect(check_in.liked_by?(nil)).to be false
    end

    it "returns false when user has not liked" do
      expect(check_in.liked_by?(user)).to be false
    end

    it "returns true when user has liked" do
      create(:challenge_check_in_like, user: user, challenge_check_in: check_in)

      expect(check_in.liked_by?(user)).to be true
    end
  end

  describe "doubts" do
    let(:story) { create(:challenge_story) }
    let(:author) { create(:challenge_participant, challenge_story: story) }
    let(:check_in) { create(:challenge_check_in, challenge_participant: author) }
    let(:friends) { create_list(:challenge_participant, 3, challenge_story: story).map(&:user) }

    it "lets friends doubt it, but not the author or strangers" do
      friends

      expect(check_in.doubtable_by?(friends.first)).to be true
      expect(check_in.doubtable_by?(author.user)).to be false
      expect(check_in.doubtable_by?(create(:user))).to be false
      expect(check_in.doubtable_by?(nil)).to be false
    end

    it "closes doubts 48 hours after the check-in" do
      friends

      travel_to(check_in.created_at + 47.hours) { expect(check_in.doubtable_by?(friends.first)).to be true }
      travel_to(check_in.created_at + 49.hours) { expect(check_in.doubtable_by?(friends.first)).to be false }
    end

    it "closes doubts with check-ins, even within 48 hours" do
      friends
      story.update_columns(start: Time.zone.today - 3.days, finish: Time.zone.today - 2.days)

      expect(check_in.doubtable_by?(friends.first)).to be false
    end

    it "disputes it once more than half of the friends doubt it, and counts it again when they withdraw" do
      check_in.doubt!(friends.first, note: "that's yesterday's photo")
      expect(check_in).to be_counted

      check_in.doubt!(friends.second)
      expect(check_in).to be_disputed

      check_in.withdraw_doubt!(friends.second)
      expect(check_in).to be_counted
    end

    it "never disputes a check-in in a pair, where one doubt only questions it" do
      friend = create(:challenge_participant, challenge_story: story).user

      check_in.doubt!(friend)

      expect(check_in).to be_counted
      expect(check_in.challenge_check_in_doubts.count).to eq 1
    end

    it "judges it again when a friend who didn't doubt leaves" do
      friends << create(:challenge_participant, challenge_story: story).user
      check_in.doubt!(friends.first)
      check_in.doubt!(friends.second)
      expect(check_in).to be_counted

      story.challenge_participants.find_by(user: friends.third).leave!

      expect(check_in.reload).to be_disputed
    end

    it "stops counting a doubt once the doubter leaves, and counts it again if they rejoin" do
      check_in.doubt!(friends.first)
      check_in.doubt!(friends.second)
      doubter = story.challenge_participants.find_by(user: friends.first)

      doubter.leave!
      expect(check_in.reload).to be_counted

      doubter.rejoin!
      expect(check_in.reload).to be_disputed
    end

    it "keeps the result once doubts have closed" do
      check_in.doubt!(friends.first)
      check_in.doubt!(friends.second)

      travel_to(check_in.created_at + 49.hours) do
        story.challenge_participants.find_by(user: friends.first).leave!
      end

      expect(check_in.reload).to be_disputed
    end

    it "lets each friend doubt it once" do
      check_in.doubt!(friends.first)

      expect { check_in.doubt!(friends.first) }.to raise_error(ActiveRecord::RecordInvalid)
    end

    it "takes disputed check-ins out of streaks and misses" do
      story.update_columns(start: Time.zone.today - 1.day)
      author.update_columns(created_at: 1.day.ago)
      check_in.update_columns(checked_in_on: Time.zone.yesterday)
      friends.first(2).each { check_in.doubt!(it) }

      participant = ChallengeParticipant.find(author.id)
      expect(participant.misses).to eq 1
      expect(participant.periods_kept).to eq 0
    end
  end
end
