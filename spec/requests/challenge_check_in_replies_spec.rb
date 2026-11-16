require "rails_helper"

RSpec.describe "ChallengeCheckInReplies", type: :request do
  let(:user) { create(:user) }
  let(:story) { create(:challenge_story) }
  let(:check_in) { create(:challenge_check_in, challenge_participant: create(:challenge_participant, challenge_story: story)) }
  let(:params) { {challenge_check_in_reply: {body: "Nice one!"}} }

  def post_reply(**options)
    post challenge_check_in_challenge_check_in_replies_path(check_in), params:, **options
  end

  it "asks visitors to sign in" do
    post_reply

    expect(response).to redirect_to(new_webauthn_session_path)
  end

  context "when signed in as a participant" do
    before do
      create(:challenge_participant, user:, challenge_story: story)
      sign_in_as(user)
    end

    it "adds the reply, resets the form and notifies the author" do
      create(:web_push_notification, user: check_in.challenge_participant.user)

      expect { post_reply(as: :turbo_stream) }
        .to change(check_in.challenge_check_in_replies, :count).by(1)
        .and have_enqueued_job(PushNotificationJob).exactly(:once)

      expect(response.body).to include(%(action="append" target="replies_challenge_check_in_#{check_in.id}"))
      expect(response.body).to include(%(action="replace" target="reply_form_challenge_check_in_#{check_in.id}"))
      expect(check_in.reload.challenge_check_in_replies_count).to eq 1
    end

    it "rejects a blank reply" do
      params[:challenge_check_in_reply][:body] = " "

      expect { post_reply(as: :turbo_stream) }.not_to change(ChallengeCheckInReply, :count)
      expect(response).to have_http_status(:unprocessable_content)
    end
  end

  it "doesn't let people outside the challenge reply" do
    sign_in_as(user)

    post_reply(as: :turbo_stream)

    expect(response).to have_http_status(:not_found)
    expect(ChallengeCheckInReply.count).to eq 0
  end

  describe "showing replies" do
    before { create(:challenge_check_in_reply, challenge_check_in: check_in, body: "How far did you go?") }

    it "shows replies to visitors without letting them reply" do
      get challenge_story_path(story)

      expect(response.body).to include("How far did you go?")
      expect(response.body).not_to include('data-can-reply="true"')
    end

    it "lets participants reply on the challenge page and in the feed" do
      create(:challenge_participant, user:, challenge_story: story)
      sign_in_as(user)

      get challenge_story_path(story)
      expect(response.body).to include('data-can-reply="true"')
      expect(response.body).to include("Add a reply")

      get challenge_check_ins_path
      expect(response.body).to include('data-can-reply="true"')
      expect(response.body).to include("How far did you go?")
    end
  end
end
