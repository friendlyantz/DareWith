require "rails_helper"

RSpec.describe "Admin users", type: :request do
  let(:admin) { create(:user, username: "friendlyantz") }
  let(:user) { create(:user, username: "maria", email: "maria@example.com") }

  context "when signed in as someone else" do
    before { sign_in_as(create(:user)) }

    it "finds nothing" do
      get admin_user_path(user)
      expect(response).to have_http_status(:not_found)

      post admin_user_sign_in_link_path(user)
      expect(response).to have_http_status(:not_found)

      delete admin_user_path(user)
      expect(response).to have_http_status(:not_found)
      expect(User.exists?(user.id)).to be true
    end
  end

  context "when signed in as the admin" do
    before { sign_in_as(admin) }

    describe "GET /admin/users/:id" do
      it "shows the user's devices and challenges" do
        create(:web_push_notification, user:, user_agent: "Mozilla/5.0 (iPhone) Safari")
        create(:challenge_participant, user:, challenge_story: create(:challenge_story, title: "Morning run"))

        get admin_user_path(user)

        expect(response.body).to include("maria@example.com")
        expect(response.body).to include("Safari on iPhone")
        expect(response.body).to include("Morning run")
        expect(response.body).to include("Send push")
      end
    end

    describe "POST /admin/users/:id/sign_in_link" do
      it "shows a link that signs the user in" do
        post admin_user_sign_in_link_path(user)

        sign_in_url = response.body[%r{http://www\.example\.com/email/session/verify\?token=[\w-]+}]
        expect(sign_in_url).to be_present
        expect(user.reload.last_email_sent_at).to be_nil

        get sign_in_url
        expect(response.body).to include("Sign in as #{user.username}")

        post sign_in_url
        follow_redirect!
        expect(session[:user_id]).to eq(user.id)
      end
    end

    describe "POST /admin/users/:id/notification" do
      it "pushes to each of the user's devices" do
        create_list(:web_push_notification, 2, user:)

        expect {
          post admin_user_notification_path(user), params: {notification: {title: "Hi", body: "How's it going?"}}
        }.to have_enqueued_job(PushNotificationJob).twice

        expect(response).to redirect_to(admin_user_path(user))
        expect(flash[:notice]).to eq("Push sent to 2 devices")
      end

      it "needs a device" do
        expect {
          post admin_user_notification_path(user), params: {notification: {title: "Hi"}}
        }.not_to have_enqueued_job(PushNotificationJob)

        expect(flash[:alert]).to eq("maria has no push devices")
      end
    end

    describe "DELETE /admin/users/:id" do
      it "deletes the user and everything they made" do
        participant = create(:challenge_participant, user:)
        check_in = create(:challenge_check_in, challenge_participant: participant)
        friend = create(:challenge_participant, challenge_story: participant.challenge_story)
        create(:challenge_reward, giver: participant, receiver: friend, challenge_story: participant.challenge_story)
        create(:challenge_reward, giver: friend, receiver: participant, challenge_story: participant.challenge_story)

        delete admin_user_path(user)

        expect(response).to redirect_to(admin_root_path)
        expect(User.exists?(user.id)).to be false
        expect(ChallengeCheckIn.exists?(check_in.id)).to be false
        expect(friend.reload).to have_attributes(given_rewards_count: 0, received_rewards_count: 0)
      end

      it "won't delete the admin" do
        delete admin_user_path(admin)

        expect(User.exists?(admin.id)).to be true
      end
    end
  end
end
