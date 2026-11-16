require "rails_helper"

RSpec.describe User, type: :model do
  describe "#can_delete_credentials?" do
    let(:user) { create(:user) }

    it "returns false when user has only one credential" do
      create(:credential, user: user)

      expect(user.can_delete_credentials?).to be false
    end

    it "returns true when user has more than one credential" do
      create_list(:credential, 2, user: user)

      expect(user.can_delete_credentials?).to be true
    end
  end

  describe "#payment_url" do
    it "turns a payment link into a URL" do
      expect(build(:user, payment_details: "paypal.me/anton").payment_url).to eq("https://paypal.me/anton")
      expect(build(:user, payment_details: "https://revolut.me/anton").payment_url).to eq("https://revolut.me/anton")
    end

    it "treats other details as plain text" do
      expect(build(:user, payment_details: "PayID 0412 345 678").payment_url).to be_nil
      expect(build(:user, payment_details: "javascript:alert(1)").payment_url).to be_nil
    end
  end

  describe "payment details" do
    it "strips blanks to nil" do
      expect(build(:user, payment_details: "  ").payment_details).to be_nil
    end

    it "is limited to 120 characters" do
      expect(build(:user, payment_details: "x" * 121)).not_to be_valid
    end
  end

  describe "#reminder_due?" do
    let(:user) { build(:user, time_zone: "Australia/Melbourne", reminder_hour: 19) }

    it "is due at the reminder hour in the user's time zone" do
      expect(user.reminder_due?(Time.utc(2026, 11, 16, 8, 30))).to be true
    end

    it "is not due at other hours" do
      expect(user.reminder_due?(Time.utc(2026, 11, 16, 19, 30))).to be false
    end

    it "is not due twice on the same local day" do
      user.last_reminded_on = Date.new(2026, 11, 16)

      expect(user.reminder_due?(Time.utc(2026, 11, 16, 8, 30))).to be false
    end

    it "is never due when turned off" do
      user.reminder_hour = nil

      expect(user.reminder_due?(Time.utc(2026, 11, 16, 8, 30))).to be false
    end
  end

  describe "#remind_to_check_in" do
    let(:user) { create(:user, time_zone: "Australia/Melbourne", reminder_hour: 19) }
    let(:story) { create(:challenge_story, title: "Morning run", start: Date.new(2026, 11, 10), finish: Date.new(2026, 11, 30)) }
    let!(:participant) { create(:challenge_participant, user: user, challenge_story: story) }
    let!(:device) { create(:web_push_notification, user: user) }
    let(:seven_pm_in_melbourne) { Time.utc(2026, 11, 16, 8, 0) }

    it "reminds about challenges without a check-in today" do
      travel_to(seven_pm_in_melbourne) do
        expect { user.remind_to_check_in }
          .to have_enqueued_job(PushNotificationJob)
          .with(device, title: "Still time to check in", body: "Morning run", path: "/today")
        expect(user.reload.last_reminded_on).to eq(Date.new(2026, 11, 16))
      end
    end

    it "counts a check-in from earlier in the local day, even if it was yesterday in UTC" do
      travel_to(seven_pm_in_melbourne) do
        create(:challenge_check_in, challenge_participant: participant).update_column(:created_at, Time.utc(2026, 11, 15, 20, 0))

        expect { user.remind_to_check_in }.not_to have_enqueued_job(PushNotificationJob)
      end
    end

    it "skips challenges that haven't started" do
      story.update!(start: Date.new(2026, 11, 20))

      travel_to(seven_pm_in_melbourne) do
        expect { user.remind_to_check_in }.not_to have_enqueued_job(PushNotificationJob)
      end
    end
  end

  describe "#send_weekly_recap" do
    let(:user) { create(:user, time_zone: "Australia/Melbourne") }
    let!(:device) { create(:web_push_notification, user:) }
    let(:sunday_evening_in_melbourne) { Time.utc(2026, 11, 22, 7, 0) }

    before do
      story = create(:challenge_story, title: "Morning run", start: Date.new(2026, 11, 10), finish: Date.new(2026, 11, 30))
      create(:challenge_participant, user:, challenge_story: story)
    end

    it "sends once on Sunday evening in the user's time zone" do
      expect { user.send_weekly_recap(sunday_evening_in_melbourne) }
        .to have_enqueued_job(PushNotificationJob)
        .with(device, title: "Your week: 0 of 7 days", body: "A new week starts tomorrow", path: "/today")
      expect(user.reload.last_recapped_on).to eq(Date.new(2026, 11, 22))

      expect { user.send_weekly_recap(sunday_evening_in_melbourne + 10.minutes) }.not_to have_enqueued_job(PushNotificationJob)
    end

    it "waits for Sunday evening" do
      expect { user.send_weekly_recap(sunday_evening_in_melbourne - 1.day) }.not_to have_enqueued_job(PushNotificationJob)
      expect { user.send_weekly_recap(sunday_evening_in_melbourne + 1.hour) }.not_to have_enqueued_job(PushNotificationJob)
    end

    it "skips users without a challenge this week" do
      user.challenge_participants.delete_all

      expect { user.send_weekly_recap(sunday_evening_in_melbourne) }.not_to have_enqueued_job(PushNotificationJob)
    end
  end

  describe "#notify" do
    let(:user) { create(:user) }

    it "enqueues one push per device" do
      create_list(:web_push_notification, 2, user: user)

      expect {
        user.notify(title: "Hello", path: "/today")
      }.to have_enqueued_job(PushNotificationJob).exactly(2).times
    end

    it "does nothing without devices" do
      expect { user.notify(title: "Hello") }.not_to have_enqueued_job(PushNotificationJob)
    end
  end

  describe "#past_challenge_stories" do
    let(:user) { create(:user) }

    it "returns completed stories the user took part in" do
      completed = create(:challenge_story, :completed)
      create(:challenge_participant, user: user, challenge_story: completed)
      create(:challenge_participant, user: user)

      expect(user.past_challenge_stories).to eq([completed])
    end
  end

  describe "#active_challenge_stories" do
    let(:user) { create(:user) }

    it "returns stories the user actively takes part in" do
      story = create(:challenge_story)
      create(:challenge_participant, user: user, challenge_story: story)

      expect(user.active_challenge_stories).to eq([story])
    end

    it "excludes stories the user has left" do
      create(:challenge_participant, :inactive, user: user)

      expect(user.active_challenge_stories).to be_empty
    end

    it "excludes completed stories" do
      create(:challenge_participant, user: user, challenge_story: create(:challenge_story, :completed))

      expect(user.active_challenge_stories).to be_empty
    end

    it "excludes other users' stories" do
      create(:challenge_participant)

      expect(user.active_challenge_stories).to be_empty
    end
  end

  describe "callbacks" do
    it "sets webauthn_id on initialize" do
      user = User.new

      expect(user.webauthn_id).to be_present
    end
  end

  describe "email authentication" do
    let(:user) { create(:user, email: "test@example.com") }

    describe "#generate_email_login_token!" do
      it "generates a token and sets expiry" do
        token = user.generate_email_login_token!

        expect(token).to be_present
        expect(token.length).to be > 20
        expect(user.email_login_token).to be_present
        expect(user.email_login_token_expires_at).to be_present
      end

      it "sets last_email_sent_at" do
        user.generate_email_login_token!

        expect(user.last_email_sent_at).to be_within(1.second).of(Time.current)
      end

      it "token expires in 24 hours" do
        user.generate_email_login_token!

        expect(user.email_login_token_expires_at).to be_within(1.second).of(24.hours.from_now)
      end
    end

    describe "#verify_email_login_token" do
      it "returns true for a valid token" do
        token = user.generate_email_login_token!

        expect(user.verify_email_login_token(token)).to be true
      end

      it "returns false for an invalid token" do
        user.generate_email_login_token!

        expect(user.verify_email_login_token("invalid-token")).to be false
      end

      it "returns false when token is expired" do
        token = user.generate_email_login_token!
        user.update!(email_login_token_expires_at: 1.hour.ago)

        expect(user.verify_email_login_token(token)).to be false
      end

      it "returns false when no token is set" do
        user.generate_email_login_token!
        token = user.email_login_token
        user.update!(email_login_token: nil)

        expect(user.verify_email_login_token(token)).to be false
      end
    end

    describe "#clear_email_login_token!" do
      it "clears token and expiry" do
        user.generate_email_login_token!
        user.clear_email_login_token!

        expect(user.email_login_token).to be_nil
        expect(user.email_login_token_expires_at).to be_nil
      end
    end

    describe "#email_login_recently_sent?" do
      it "returns true if email was sent recently" do
        user.update!(last_email_sent_at: 5.minutes.ago)

        expect(user.email_login_recently_sent?).to be true
      end

      it "returns false if no email was sent" do
        user.update!(last_email_sent_at: nil)

        expect(user.email_login_recently_sent?).to be false
      end

      it "returns false if email was sent over 15 minutes ago" do
        user.update!(last_email_sent_at: 20.minutes.ago)

        expect(user.email_login_recently_sent?).to be false
      end
    end

    describe "#email_verified?" do
      it "returns true when email_verified_at is set" do
        user.update!(email_verified_at: Time.current)

        expect(user.email_verified?).to be true
      end

      it "returns false when email_verified_at is nil" do
        expect(user.email_verified?).to be false
      end
    end

    describe "#verify_email!" do
      it "sets email_verified_at" do
        user.verify_email!

        expect(user.email_verified_at).to be_present
        expect(user.email_verified_at).to be_within(1.second).of(Time.current)
      end
    end

    describe ".find_by_email_login_token" do
      it "finds user by valid token" do
        token = user.generate_email_login_token!

        found_user = User.find_by_email_login_token(token)

        expect(found_user).to eq(user)
      end

      it "returns nil for invalid token" do
        found_user = User.find_by_email_login_token("invalid-token")

        expect(found_user).to be_nil
      end
    end
  end

  describe "#next_round_invites" do
    let(:user) { create(:user) }
    let(:round_one) { create(:challenge_story, :finished, completed: true) }
    let!(:round_two) { round_one.next_round.tap(&:save!) }

    before do
      create(:challenge_participant, user:, challenge_story: round_one)
      create(:challenge_participant, challenge_story: round_two)
    end

    it "includes the next round of a challenge the user was in" do
      expect(user.next_round_invites).to eq [round_two]
    end

    it "skips rounds the user joined or left" do
      participant = create(:challenge_participant, user:, challenge_story: round_two)
      expect(user.next_round_invites).to be_empty

      participant.leave!
      expect(user.next_round_invites).to be_empty
    end

    it "skips the next round when the user had left the previous one" do
      user.challenge_participants.find_by!(challenge_story: round_one).leave!

      expect(user.next_round_invites).to be_empty
    end

    it "skips full and finished rounds" do
      (ChallengeStory::MAX_PARTICIPANTS - 1).times { create(:challenge_participant, challenge_story: round_two) }
      expect(user.next_round_invites).to be_empty

      round_two.challenge_participants.last.destroy!
      round_two.update!(start: Time.zone.today - 10.days, finish: Time.zone.today - 2.days)
      expect(user.next_round_invites).to be_empty
    end
  end
end
