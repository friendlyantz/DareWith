require "rails_helper"

RSpec.describe "Profiles", type: :request do
  describe "GET /me" do
    it "asks visitors to sign in" do
      get profile_path

      expect(response).to redirect_to(new_webauthn_session_path)
    end

    context "when signed in" do
      let(:user) { create(:user, username: "anton") }

      before { sign_in_as(user) }

      it "shows the user and their finished challenges" do
        create(:challenge_participant, user: user, challenge_story: create(:challenge_story, :completed, title: "Old one"))
        create(:challenge_participant, user: user, challenge_story: create(:challenge_story, title: "Running one"))

        get profile_path

        expect(response.body).to include("anton")
        expect(response.body).to include("1 active challenge")
        expect(response.body).to include("Old one")
        expect(response.body).not_to include("Running one")
      end
    end
  end

  describe "PATCH /me" do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    it "sets the reminder hour" do
      patch profile_path, params: {user: {reminder_hour: "8"}}

      expect(user.reload.reminder_hour).to eq(8)
      expect(flash[:notice]).to eq("Reminder set for 08:00")
    end

    it "turns the reminder off" do
      patch profile_path, params: {user: {reminder_hour: ""}}

      expect(user.reload.reminder_hour).to be_nil
    end
  end

  describe "time zone from the browser" do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    it "remembers a valid time zone" do
      cookies[:time_zone] = "Australia/Melbourne"

      get profile_path

      expect(user.reload.time_zone).to eq("Australia/Melbourne")
    end

    it "ignores an invalid one" do
      cookies[:time_zone] = "Mars/Olympus"

      get profile_path

      expect(user.reload.time_zone).to eq("UTC")
    end

    it "uses it for today" do
      user.update!(time_zone: "Australia/Melbourne")
      participant = create(:challenge_participant, user: user, challenge_story: create(:challenge_story, start: Date.new(2026, 11, 10)))

      travel_to(Time.utc(2026, 11, 16, 2, 0)) do
        create(:challenge_check_in, challenge_participant: participant).update_column(:created_at, Time.utc(2026, 11, 15, 20, 0))

        get today_path

        expect(response.body).to include("1 of 1 done today")
      end
    end
  end
end
