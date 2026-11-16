require "rails_helper"

RSpec.describe "ChallengeRewards", type: :request do
  let(:user) { create(:user) }
  let(:story) { create(:challenge_story) }
  let!(:giver) { create(:challenge_participant, user: user, challenge_story: story) }
  let!(:receiver) { create(:challenge_participant, challenge_story: story) }

  describe "GET /challenge_stories/:challenge_story_id/challenge_rewards" do
    before { sign_in_as(user) }

    it "returns the rewards index" do
      get challenge_story_challenge_rewards_path(story)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "settling up" do
    before do
      receiver.user.update!(payment_details: "paypal.me/maya")
      create(:challenge_reward, giver: giver, receiver: receiver, challenge_story: story)
      sign_in_as(user)
    end

    it "shows the giver how to pay once time is up" do
      story.update!(start: Time.zone.today - 10.days, finish: Time.zone.today - 1.day)

      get challenge_story_challenge_rewards_path(story)

      expect(response.body).to include("Settle up with #{receiver.name}")
      expect(response.body).to include('href="https://paypal.me/maya"')
    end

    it "doesn't show it while the challenge is running" do
      get challenge_story_challenge_rewards_path(story)

      expect(response.body).not_to include("Settle up with")
    end
  end

  describe "GET /challenge_stories/:challenge_story_id/challenge_rewards/new" do
    before { sign_in_as(user) }

    it "returns the new reward form" do
      get new_challenge_story_challenge_reward_path(story)

      expect(response).to have_http_status(:ok)
    end
  end

  describe "POST /challenge_stories/:challenge_story_id/challenge_rewards" do
    before { sign_in_as(user) }

    context "with valid params" do
      let(:valid_params) do
        {
          challenge_reward: {
            receiver_id: receiver.id,
            description: "Coffee treat!"
          }
        }
      end

      it "creates a new reward" do
        expect {
          post challenge_story_challenge_rewards_path(story), params: valid_params
        }.to change(ChallengeReward, :count).by(1)

        expect(response).to redirect_to(challenge_story_challenge_rewards_path(story))
      end
    end

    context "when the receiver has notifications on" do
      it "notifies the receiver" do
        device = create(:web_push_notification, user: receiver.user)

        expect {
          post challenge_story_challenge_rewards_path(story),
            params: {challenge_reward: {receiver_id: receiver.id, description: "Coffee treat!"}}
        }.to have_enqueued_job(PushNotificationJob).with(device, hash_including(title: "#{giver.name} pledged you a reward"))
      end
    end

    context "after the challenge has ended" do
      it "does not accept new pledges" do
        story.update!(start: Time.zone.today - 10.days, finish: Time.zone.today - 3.days)

        expect {
          post challenge_story_challenge_rewards_path(story),
            params: {challenge_reward: {receiver_id: receiver.id, description: "Late coffee"}}
        }.not_to change(ChallengeReward, :count)
      end
    end

    context "when posting someone else as the giver" do
      let(:third) { create(:challenge_participant, challenge_story: story) }

      it "always records the current user as the giver" do
        post challenge_story_challenge_rewards_path(story),
          params: {challenge_reward: {giver_id: third.id, receiver_id: receiver.id, description: "Forged"}}

        expect(ChallengeReward.last.giver).to eq(giver)
      end
    end

    context "when rewarding self" do
      let(:invalid_params) do
        {
          challenge_reward: {
            receiver_id: giver.id,
            description: "Self reward"
          }
        }
      end

      it "does not create a reward" do
        expect {
          post challenge_story_challenge_rewards_path(story), params: invalid_params
        }.not_to change(ChallengeReward, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /challenge_stories/:challenge_story_id/challenge_rewards/:id/fulfill" do
    let!(:reward) { create(:challenge_reward, giver: giver, receiver: receiver, challenge_story: story) }

    context "when receiver fulfills" do
      before { sign_in_as(receiver.user) }

      it "marks the reward as fulfilled" do
        patch fulfill_challenge_story_challenge_reward_path(story, reward)

        expect(reward.reload).to be_fulfilled
        expect(response).to redirect_to(challenge_story_challenge_rewards_path(story))
      end

      it "tells the giver" do
        device = create(:web_push_notification, user: giver.user)

        expect {
          patch fulfill_challenge_story_challenge_reward_path(story, reward)
        }.to have_enqueued_job(PushNotificationJob).with(device, hash_including(title: "#{receiver.name} received your reward"))
      end
    end

    context "when non-receiver tries to fulfill" do
      before { sign_in_as(user) }

      it "redirects with alert" do
        patch fulfill_challenge_story_challenge_reward_path(story, reward)

        expect(reward.reload).not_to be_fulfilled
        expect(flash[:alert]).to include("pledged to you")
      end
    end
  end

  describe "PATCH /challenge_stories/:challenge_story_id/challenge_rewards/:id/cancel" do
    let!(:reward) { create(:challenge_reward, giver: giver, receiver: receiver, challenge_story: story) }

    context "when giver cancels" do
      before { sign_in_as(user) }

      it "marks the reward as canceled" do
        patch cancel_challenge_story_challenge_reward_path(story, reward)

        expect(reward.reload).to be_canceled
        expect(response).to redirect_to(challenge_story_challenge_rewards_path(story))
      end
    end

    context "when non-giver tries to cancel" do
      before { sign_in_as(receiver.user) }

      it "redirects with alert" do
        patch cancel_challenge_story_challenge_reward_path(story, reward)

        expect(reward.reload).not_to be_canceled
        expect(flash[:alert]).to include("pledged")
      end
    end
  end
end
