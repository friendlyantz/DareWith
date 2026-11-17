require "rails_helper"

RSpec.describe ChallengeCheckIn, type: :model do
  describe "validations" do
    describe "one_comment_per_day_per_participant" do
      let(:challenge_participant) { create(:challenge_participant) }
      let(:story) { challenge_participant.challenge_story }

      it "allows first check-in of the day" do
        check_in = build(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)

        expect(check_in).to be_valid
      end

      it "prevents second check-in on same day" do
        create(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)
        second_check_in = build(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)

        expect(second_check_in).not_to be_valid
        expect(second_check_in.errors[:base]).to include("You can only check in once per day")
      end

      it "is enforced by the database too" do
        create(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)
        second_check_in = build(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story, checked_in_on: Time.zone.today)

        expect { second_check_in.save(validate: false) }.to raise_error(ActiveRecord::RecordNotUnique)
      end

      it "allows check-in on different day" do
        create(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story, created_at: 1.day.ago)
        today_check_in = build(:challenge_check_in, challenge_participant: challenge_participant, challenge_story: story)

        expect(today_check_in).to be_valid
      end
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
end
