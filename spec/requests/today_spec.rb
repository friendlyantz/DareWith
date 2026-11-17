require "rails_helper"

RSpec.describe "Today", type: :request do
  describe "GET /today" do
    it "asks visitors to sign in" do
      get today_path

      expect(response).to redirect_to(new_webauthn_session_path)
    end

    context "when signed in" do
      let(:user) { create(:user) }
      let(:story) { create(:challenge_story, title: "Morning run") }
      let!(:participant) { create(:challenge_participant, user: user, challenge_story: story) }

      before { sign_in_as(user) }

      it "shows this week's progress for a weekly challenge" do
        story.update!(cadence: :weekly, times_per_period: 2, start: Time.zone.today - 1.day, finish: Time.zone.today + 12.days)
        create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.yesterday)

        get today_path

        expect(response.body).to include("1 of 2 this week · 6 days left")
        expect(response.body).to include("0 of 1 done today")
      end

      it "counts a weekly challenge as done once the week is" do
        story.update!(cadence: :weekly, times_per_period: 1, start: Time.zone.today - 1.day, finish: Time.zone.today + 12.days)
        create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.yesterday)

        get today_path

        expect(response.body).to include("Week done").and include("1 of 1 done today")
      end

      it "invites the user to the next round of a past challenge" do
        round_one = create(:challenge_story, :finished, completed: true, title: "Gym")
        create(:challenge_participant, user:, challenge_story: round_one)
        round_two = round_one.next_round.tap(&:save!)
        create(:challenge_participant, challenge_story: round_two, user: create(:user, username: "maria"))

        get today_path

        expect(response.body).to include("Round 2 of Gym")
        expect(response.body).to include("maria is in")
        expect(response.body).to include(challenge_participants_path(challenge_story_id: round_two.id))
      end

      it "says when a freeze saved the streak yesterday" do
        (2..8).each { create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.today - it) }

        get today_path

        expect(response.body).to include("A freeze saved your 7 days in a row yesterday")
      end

      it "offers a check-in for each active challenge" do
        get today_path

        expect(response.body).to include("Morning run")
        expect(response.body).to include("0 of 1 done today")
        expect(response.body).to include(new_challenge_story_challenge_check_in_path(story))
      end

      it "shows challenges already checked in today as done" do
        create(:challenge_check_in, challenge_participant: participant)

        get today_path

        expect(response.body).to include("1 of 1 done today")
        expect(response.body).not_to include(new_challenge_story_challenge_check_in_path(story))
      end

      it "moves ended challenges to wrap up, outside the daily count" do
        ended = create(:challenge_story, :finished, title: "Old push-ups")
        create(:challenge_participant, user: user, challenge_story: ended)

        get today_path

        expect(response.body).to include("0 of 1 done today")
        expect(response.body).to include("Wrap up")
        expect(response.body).to include(challenge_story_challenge_rewards_path(ended))
      end

      it "leaves out challenges the user has left or that are completed" do
        participant.leave!
        create(:challenge_participant, user: user, challenge_story: create(:challenge_story, :completed, title: "Old one"))

        get today_path

        expect(response.body).not_to include("Morning run")
        expect(response.body).not_to include("Old one")
        expect(response.body).to include("No active challenges")
      end
    end
  end
end
