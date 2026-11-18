require "rails_helper"

RSpec.describe ChallengeStory, type: :model do
  describe "validations" do
    it "validates finish cannot be earlier than start" do
      story = build(:challenge_story, start: Time.zone.today, finish: Time.zone.today - 1.day)

      expect(story).not_to be_valid
      expect(story.errors[:finish]).to include("cannot be earlier than the start date")
    end

    it "validates description length" do
      story = build(:challenge_story, description: "a" * 501)

      expect(story).not_to be_valid
    end
  end

  describe "#finished?" do
    it "returns true when finish date is in the past" do
      story = build(:challenge_story, finish: Time.zone.today - 1.day)

      expect(story.finished?).to be true
    end

    it "returns false when finish date is today or future" do
      story = build(:challenge_story, finish: Time.zone.today)

      expect(story.finished?).to be false
    end
  end

  describe "#current_day" do
    it "counts the start date as day 1" do
      story = build(:challenge_story, start: Time.zone.today, finish: Time.zone.today + 6.days)

      expect(story.current_day).to eq(1)
      expect(story.duration_in_days).to eq(7)
    end

    it "counts days since the start" do
      story = build(:challenge_story, start: Time.zone.today - 4.days, finish: Time.zone.today + 2.days)

      expect(story.current_day).to eq(5)
    end

    it "stays on the last day after the finish" do
      story = build(:challenge_story, :finished)

      expect(story.current_day).to eq(story.duration_in_days)
    end
  end

  describe "#accepting_check_ins?" do
    it "is true while the challenge runs" do
      expect(build(:challenge_story)).to be_accepting_check_ins
    end

    it "allows one extra day after the finish" do
      story = build(:challenge_story, start: Time.zone.today - 7.days, finish: Time.zone.today - 1.day)

      expect(story).to be_accepting_check_ins
    end

    it "is false later than a day after the finish" do
      expect(build(:challenge_story, :finished)).not_to be_accepting_check_ins
    end

    it "is false once completed" do
      expect(build(:challenge_story, :completed)).not_to be_accepting_check_ins
    end
  end

  describe "#completes_at" do
    it "is once the grace day is over in the last time zone" do
      story = build(:challenge_story, finish: Date.new(2026, 11, 16))

      expect(story.completes_at).to eq(Time.utc(2026, 11, 18, 12))
    end
  end

  describe "#at_capacity?" do
    let(:story) { create(:challenge_story) }

    it "returns false when under capacity" do
      create_list(:challenge_participant, 2, challenge_story: story)

      expect(story.at_capacity?).to be false
    end

    it "returns true when at max participants" do
      create_list(:challenge_participant, ChallengeStory::MAX_PARTICIPANTS, challenge_story: story)

      expect(story.at_capacity?).to be true
    end
  end

  describe "#available_spots" do
    let(:story) { create(:challenge_story) }

    it "returns remaining spots" do
      create_list(:challenge_participant, 2, challenge_story: story)

      expect(story.available_spots).to eq(ChallengeStory::MAX_PARTICIPANTS - 2)
    end
  end

  describe "#mark_complete!" do
    let(:story) { create(:challenge_story) }

    it "marks the story as completed" do
      story.mark_complete!

      expect(story.reload).to be_completed
    end

    it "checks the active participants for new badges" do
      participant = create(:challenge_participant, challenge_story: story)
      create(:challenge_participant, :inactive, challenge_story: story)

      expect { story.mark_complete! }.to have_enqueued_job(BadgeAwardJob).with(participant.user).exactly(:once)
    end
  end

  describe "#find_or_activate_participant!" do
    let(:story) { create(:challenge_story) }
    let(:user) { create(:user) }

    context "when user is not a participant" do
      it "creates a new active participant" do
        participant = story.find_or_activate_participant!(user)

        expect(participant).to be_persisted
        expect(participant).to be_active
        expect(participant.user).to eq(user)
      end
    end

    context "when user is an inactive participant" do
      let!(:participant) { create(:challenge_participant, :inactive, user: user, challenge_story: story) }

      it "reactivates the participant" do
        result = story.find_or_activate_participant!(user)

        expect(result.id).to eq(participant.id)
        expect(result).to be_active
      end
    end

    context "when user is already active" do
      let!(:participant) { create(:challenge_participant, user: user, challenge_story: story) }

      it "returns existing participant" do
        result = story.find_or_activate_participant!(user)

        expect(result.id).to eq(participant.id)
      end
    end
  end

  describe "#liked_by?" do
    let(:story) { create(:challenge_story) }
    let(:user) { create(:user) }

    it "returns false when user is nil" do
      expect(story.liked_by?(nil)).to be false
    end

    it "returns false when user has not liked" do
      expect(story.liked_by?(user)).to be false
    end

    it "returns true when user has liked" do
      create(:challenge_story_like, user: user, challenge_story: story)

      expect(story.liked_by?(user)).to be true
    end
  end

  describe "scopes" do
    describe ".active" do
      it "returns non-completed stories" do
        active = create(:challenge_story, completed: false)
        create(:challenge_story, :completed)

        expect(ChallengeStory.active).to eq([active])
      end
    end

    describe ".completed" do
      it "returns completed stories" do
        create(:challenge_story, completed: false)
        completed = create(:challenge_story, :completed)

        expect(ChallengeStory.completed).to eq([completed])
      end
    end
  end

  describe "goal" do
    it "is a plain daily challenge by default" do
      story = create(:challenge_story)

      expect(story).to be_daily
      expect(story.times_per_period).to eq 1
      expect(story.goal).not_to be_measured
    end

    it "allows up to six times a week" do
      expect(build(:challenge_story, :weekly, times_per_period: 6)).to be_valid
      expect(build(:challenge_story, :weekly, times_per_period: 7)).not_to be_valid
    end

    it "ignores a weekly count on a daily challenge, since the form always sends one" do
      expect(create(:challenge_story, cadence: :daily, times_per_period: 3).times_per_period).to eq 1
    end

    it "runs weekly challenges for whole weeks" do
      story = build(:challenge_story, :weekly, start: Date.new(2026, 11, 17), finish: Date.new(2026, 11, 26))

      expect(story).not_to be_valid
      expect(story.errors[:finish]).to include("must make whole weeks for a weekly challenge, e.g. 30 Nov")
    end

    it "rejects unknown units instead of raising" do
      expect(build(:challenge_story, unit: "furlongs")).not_to be_valid
    end

    it "drops a target without a unit" do
      story = create(:challenge_story, target_amount: 50, target_scope: :each_time)

      expect(story).to have_attributes(target_amount: nil, target_scope: nil)
    end

    it "drops the scope without a target amount" do
      story = create(:challenge_story, unit: :reps, target_scope: :each_time)

      expect(story.target_scope).to be_nil
    end

    it "needs a whole-number target for reps" do
      expect(build(:challenge_story, unit: :reps, target_amount: 50.5, target_scope: :each_time)).not_to be_valid
      expect(build(:challenge_story, unit: :km, target_amount: 5.5, target_scope: :each_time)).to be_valid
    end

    it "keeps a saved whole-number target valid when other fields change" do
      story = create(:challenge_story, unit: :reps, target_amount: 50, target_scope: :each_time).reload

      expect(story.update(title: "Renamed")).to be true
    end

    it "needs to say what a penalty costs" do
      expect(build(:challenge_story, penalty_mode: :per_miss, penalty: " ")).not_to be_valid
    end

    it "rejects a target that isn't positive" do
      expect(build(:challenge_story, unit: :reps, target_amount: 0, target_scope: :each_time)).not_to be_valid
    end

    it "is fixed once someone has checked in" do
      story = create(:challenge_story, unit: :reps)
      create(:challenge_check_in, challenge_participant: create(:challenge_participant, challenge_story: story), amount: 10)

      expect(story.reload.update(unit: :minutes)).to be false
      expect(story.errors[:base]).to include("The goal and penalty can't change once someone has checked in")
      expect(story.reload.update(title: "Renamed")).to be true
    end
  end

  describe "#ranked_participants" do
    let(:story) { create(:challenge_story, start: Time.zone.today - 2.days, finish: Time.zone.today + 5.days, unit: :km) }
    let!(:steady) { create(:challenge_participant, challenge_story: story) }
    let!(:sprinter) { create(:challenge_participant, challenge_story: story) }

    before do
      3.times { create(:challenge_check_in, challenge_participant: steady, amount: 2, checked_in_on: Time.zone.today - it) }
      create(:challenge_check_in, challenge_participant: sprinter, amount: 20)
    end

    it "ranks by days kept, then by total" do
      expect(story.reload.ranked_participants).to eq [steady, sprinter]
    end

    it "ranks by total for a target by the end" do
      story.update_columns(target_amount: 50, target_scope: "total")

      expect(story.reload.ranked_participants).to eq [sprinter, steady]
    end
  end

  describe "rounds" do
    let(:round_one) { create(:challenge_story, :finished, title: "Gym", description: "Any workout counts") }

    it "keeps the goal in the next round" do
      round_one.update!(finish: round_one.start + 13.days, cadence: :weekly, times_per_period: 3, unit: :km, target_amount: 5, target_scope: :each_time)

      expect(round_one.next_round).to have_attributes(cadence: "weekly", times_per_period: 3, unit: "km", target_amount: 5, target_scope: "each_time")
    end

    it "keeps the penalty in the next round" do
      round_one.update!(penalty_mode: :most_misses, penalty: "buys lunch")

      expect(round_one.next_round).to have_attributes(penalty_mode: "most_misses", penalty: "buys lunch")
    end

    it "starts the next round today with the same rules and length" do
      travel_to(Time.zone.local(2026, 11, 17, 9)) do
        next_round = round_one.next_round

        expect(next_round).to have_attributes(title: "Gym", description: "Any workout counts", start: Date.new(2026, 11, 17), previous_challenge_story: round_one)
        expect(next_round.duration_in_days).to eq(round_one.duration_in_days)
      end
    end

    it "numbers the rounds" do
      round_two = round_one.next_round.tap(&:save!)

      expect(round_two.round).to eq 2
      expect(round_two.next_round.tap(&:save!).round).to eq 3
    end

    it "allows only one next round" do
      round_one.next_round.save!

      expect { round_one.next_round.save! }.to raise_error(ActiveRecord::RecordNotUnique)
    end

    it "invites everyone else from the previous round" do
      starter = create(:challenge_participant, challenge_story: round_one)
      friend = create(:challenge_participant, challenge_story: round_one)
      create(:challenge_participant, :inactive, challenge_story: round_one)
      friend_device = create(:web_push_notification, user: friend.user)
      create(:web_push_notification, user: starter.user)
      round_two = round_one.next_round.tap(&:save!)

      expect { round_two.invite_to_next_round(by: starter.user) }
        .to have_enqueued_job(PushNotificationJob).exactly(:once)
        .with(friend_device, title: "#{starter.user.username} started round 2 of Gym", body: "Same rules, new dates. Tap to join.", path: "/challenge_stories/#{round_two.id}")
    end
  end
end
