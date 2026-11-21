require "rails_helper"

RSpec.describe ChallengeParticipant, type: :model do
  describe "#leave!" do
    let(:participant) { create(:challenge_participant) }

    it "marks participant as inactive" do
      participant.leave!

      expect(participant.reload).to be_inactive
    end
  end

  describe "#checked_in_today?" do
    let(:participant) { create(:challenge_participant) }

    it "is false without check-ins" do
      expect(participant.checked_in_today?).to be false
    end

    it "is true after a check-in today" do
      create(:challenge_check_in, challenge_participant: participant)

      expect(participant.checked_in_today?).to be true
    end

    it "is false when the last check-in was yesterday" do
      create(:challenge_check_in, challenge_participant: participant, checked_in_on: Date.yesterday)

      expect(participant.checked_in_today?).to be false
    end
  end

  describe "weekly challenges" do
    let(:start) { Date.new(2026, 11, 18) }
    let(:participant) { create(:challenge_participant, challenge_story: create(:challenge_story, :weekly, start:, times_per_period: 3)) }

    def check_in(*days_from_start)
      days_from_start.each { create(:challenge_check_in, challenge_participant: participant, checked_in_on: start + it) }
    end

    it "is done for the week after enough check-ins" do
      check_in(0, 1, 2)

      travel_to(start + 4.days) { expect(participant.reload).to be_done_for_now }
    end

    it "only reminds once the days left are just enough" do
      check_in(0)

      travel_to(start + 3.days) { expect(participant.reload.reminder_due_today?).to be false }
      travel_to(start + 5.days) { expect(participant.reload.reminder_due_today?).to be true }
    end

    it "keeps showing the last week on the grace day after the end" do
      check_in(21, 22, 23)

      travel_to(start + 28.days) do
        expect(participant.reload.check_ins_this_period).to eq 3
        expect(participant).to be_done_for_now
      end
    end

    it "counts weeks kept for the leaderboard" do
      check_in(0, 1, 2, 7, 8, 14, 15, 16)

      expect(participant.reload.periods_kept).to eq 2
    end
  end

  describe "#misses" do
    let(:story) { create(:challenge_story, start: Time.zone.today - 8.days, finish: Time.zone.today + 5.days) }

    it "counts only the days since joining" do
      late = create(:challenge_participant, challenge_story: story, created_at: 2.days.ago)

      expect(late.misses).to eq 2
    end

    it "skips a week joined partway through" do
      story = create(:challenge_story, :weekly, start: Time.zone.today - 10.days, times_per_period: 3)
      late = create(:challenge_participant, challenge_story: story, created_at: 9.days.ago)
      on_time = create(:challenge_participant, challenge_story: story)

      expect(late.misses).to eq 0
      expect(on_time.misses).to eq 1
    end
  end

  describe "#rejoin!" do
    let(:participant) { create(:challenge_participant, :inactive) }

    it "marks participant as active" do
      participant.rejoin!

      expect(participant.reload).to be_active
    end
  end

  describe "callbacks" do
    describe "set_default_name" do
      it "sets name from username on create" do
        user = create(:user, username: "testuser")
        participant = create(:challenge_participant, user: user, name: nil)

        expect(participant.name).to eq("testuser")
      end
    end
  end

  describe "scopes" do
    let(:story) { create(:challenge_story) }

    describe ".active" do
      it "returns only active participants" do
        active = create(:challenge_participant, challenge_story: story, status: :active)
        create(:challenge_participant, :inactive, challenge_story: story)

        expect(ChallengeParticipant.active).to eq([active])
      end
    end

    describe ".inactive" do
      it "returns only inactive participants" do
        create(:challenge_participant, challenge_story: story, status: :active)
        inactive = create(:challenge_participant, :inactive, challenge_story: story)

        expect(ChallengeParticipant.inactive).to eq([inactive])
      end
    end
  end

  describe "#has_pledged_to_all_active_participants?" do
    let(:story) { create(:challenge_story) }
    let(:participant1) { create(:challenge_participant, challenge_story: story) }
    let(:participant2) { create(:challenge_participant, challenge_story: story) }
    let(:participant3) { create(:challenge_participant, challenge_story: story) }

    context "when there are no other active participants" do
      it "returns true" do
        solo_participant = create(:challenge_participant, challenge_story: create(:challenge_story))

        expect(solo_participant.has_pledged_to_all_active_participants?).to be true
      end
    end

    context "when pledged to all active participants" do
      it "returns true" do
        create(:challenge_reward, giver: participant1, receiver: participant2, challenge_story: story)
        create(:challenge_reward, giver: participant1, receiver: participant3, challenge_story: story)

        expect(participant1.has_pledged_to_all_active_participants?).to be true
      end
    end

    context "when not pledged to all active participants" do
      before do
        # Ensure all participants exist
        participant1
        participant2
        participant3
      end

      it "returns false" do
        create(:challenge_reward, giver: participant1, receiver: participant2, challenge_story: story)

        expect(participant1.has_pledged_to_all_active_participants?).to be false
      end
    end

    context "when inactive participants exist" do
      it "ignores inactive participants" do
        create(:challenge_participant, :inactive, challenge_story: story)
        create(:challenge_reward, giver: participant1, receiver: participant2, challenge_story: story)
        create(:challenge_reward, giver: participant1, receiver: participant3, challenge_story: story)

        expect(participant1.has_pledged_to_all_active_participants?).to be true
      end
    end
  end

  describe "#unpledged_participants" do
    let(:story) { create(:challenge_story) }
    let(:participant1) { create(:challenge_participant, challenge_story: story) }
    let(:participant2) { create(:challenge_participant, challenge_story: story) }
    let(:participant3) { create(:challenge_participant, challenge_story: story) }

    it "returns participants without pledges" do
      create(:challenge_reward, giver: participant1, receiver: participant2, challenge_story: story)
      participant3 # ensure participant3 exists

      expect(participant1.unpledged_participants).to contain_exactly(participant3)
    end

    it "excludes inactive participants" do
      create(:challenge_participant, :inactive, challenge_story: story)
      participant2 # ensure participant2 exists
      participant3 # ensure participant3 exists

      expect(participant1.unpledged_participants).to contain_exactly(participant2, participant3)
    end

    it "excludes self" do
      participant2 # ensure participant2 exists
      participant3 # ensure participant3 exists

      expect(participant1.unpledged_participants).not_to include(participant1)
    end
  end

  describe "#missing_pledges?" do
    let(:story) { create(:challenge_story) }
    let(:participant1) { create(:challenge_participant, challenge_story: story) }
    let(:participant2) { create(:challenge_participant, challenge_story: story) }

    it "returns true when pledges are missing" do
      participant1
      participant2 # ensure participant2 exists

      expect(participant1.missing_pledges?).to be true
    end

    it "returns false when all pledges are made" do
      create(:challenge_reward, giver: participant1, receiver: participant2, challenge_story: story)

      expect(participant1.missing_pledges?).to be false
    end
  end

  describe "weekly targets" do
    let(:start) { Date.new(2026, 11, 18) }
    let(:story) { create(:challenge_story, :weekly, start:, times_per_period: 3, unit: :km, target_amount: 15, target_scope: :each_period) }
    let(:participant) { create(:challenge_participant, challenge_story: story) }

    def check_in(*days_from_start, amount:)
      days_from_start.each { create(:challenge_check_in, challenge_participant: participant, challenge_story: story, checked_in_on: start + it, amount:) }
    end

    it "reminds on the last day when the days are done but the distance isn't" do
      check_in(0, 1, 2, amount: 4)

      travel_to(start + 5.days) { expect(participant.reload.reminder_due_today?).to be false }
      travel_to(start + 6.days) { expect(participant.reload.reminder_due_today?).to be true }
    end

    it "counts the grace day toward the last week's distance" do
      check_in(21, 22, 23, amount: 4)
      check_in(28, amount: 3)

      travel_to(start + 28.days) do
        expect(participant.reload.amount_this_period).to eq 15
        expect(participant).to be_period_kept
      end
    end
  end
end
