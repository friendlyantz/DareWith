require "rails_helper"

RSpec.describe "ChallengeNudges", type: :request do
  let(:user) { create(:user) }
  let(:story) { create(:challenge_story) }
  let(:friend) { create(:challenge_participant, challenge_story: story) }

  def post_nudge(**options)
    post challenge_participant_challenge_nudges_path(friend), **options
  end

  it "asks visitors to sign in" do
    post_nudge

    expect(response).to redirect_to(new_webauthn_session_path)
  end

  context "when signed in as a participant who checked in" do
    before do
      create(:challenge_check_in, challenge_participant: create(:challenge_participant, user:, challenge_story: story))
      create(:web_push_notification, user: friend.user)
      sign_in_as(user)
    end

    it "nudges the friend and shows it was sent" do
      expect { post_nudge(as: :turbo_stream) }
        .to change(friend.received_nudges, :count).by(1)
        .and have_enqueued_job(PushNotificationJob).exactly(:once)

      expect(response.body).to include(%(target="nudge_challenge_participant_#{friend.id}"))
      expect(response.body).to include("Nudged")
    end

    it "nudges each friend only once a day" do
      post_nudge(as: :turbo_stream)

      expect { post_nudge(as: :turbo_stream) }.not_to have_enqueued_job(PushNotificationJob)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "doesn't let people outside the challenge nudge" do
    sign_in_as(user)

    post_nudge(as: :turbo_stream)

    expect(response).to have_http_status(:not_found)
  end
end
