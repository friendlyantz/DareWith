require "rails_helper"

RSpec.describe "ChallengeCheckInDoubts", type: :request do
  let(:user) { create(:user) }
  let(:story) { create(:challenge_story) }
  let(:check_in) { create(:challenge_check_in, challenge_participant: create(:challenge_participant, challenge_story: story)) }
  let(:params) { {challenge_check_in_doubt: {note: "That's yesterday's photo"}} }

  it "asks visitors to sign up" do
    post challenge_check_in_challenge_check_in_doubt_path(check_in), params: params

    expect(response).to redirect_to(new_webauthn_registration_path)
  end

  context "when signed in as a friend in the challenge" do
    before do
      create(:challenge_participant, user:, challenge_story: story)
      sign_in_as(user)
    end

    it "doubts the check-in with a note and tells the author" do
      create(:web_push_notification, user: check_in.challenge_participant.user)

      expect { post challenge_check_in_challenge_check_in_doubt_path(check_in), params: params }
        .to change(check_in.challenge_check_in_doubts, :count).by(1)
        .and have_enqueued_job(PushNotificationJob).exactly(:once)

      expect(ChallengeCheckInDoubt.last).to have_attributes(user:, note: "That's yesterday's photo")
      expect(response).to redirect_to(challenge_story_path(story, anchor: "challenge_check_in_#{check_in.id}"))
    end

    it "withdraws the doubt" do
      check_in.doubt!(user)

      expect { delete challenge_check_in_challenge_check_in_doubt_path(check_in) }
        .to change(check_in.challenge_check_in_doubts, :count).by(-1)
    end

    it "refuses once doubts have closed" do
      travel_to(check_in.created_at + 49.hours) do
        post challenge_check_in_challenge_check_in_doubt_path(check_in), params: params
      end

      expect(response).to have_http_status(:forbidden)
    end

    it "shows the doubt on the check-in" do
      check_in.doubt!(user, note: "That's yesterday's photo")

      get challenge_story_path(story)

      expect(response.body).to include("Doubted by #{user.username}")
      expect(response.body).to include("That&#39;s yesterday&#39;s photo")
    end
  end

  it "doesn't let the author doubt their own check-in" do
    sign_in_as(check_in.challenge_participant.user)

    post challenge_check_in_challenge_check_in_doubt_path(check_in), params: params

    expect(response).to have_http_status(:forbidden)
  end
end
