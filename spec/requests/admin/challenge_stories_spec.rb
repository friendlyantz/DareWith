require "rails_helper"

RSpec.describe "Admin challenge stories", type: :request do
  let(:story) { create(:challenge_story, :finished, completed: true, title: "Gym") }
  let!(:participant) { create(:challenge_participant, challenge_story: story) }

  describe "DELETE /admin/challenge_stories/:id" do
    it "is not found for participants" do
      sign_in_as(participant.user)

      delete admin_challenge_story_path(story)

      expect(response).to have_http_status(:not_found)
      expect(ChallengeStory.exists?(story.id)).to be true
    end

    context "when signed in as the admin" do
      before { sign_in_as(create(:user, username: "friendlyantz")) }

      it "deletes the challenge with everything in it, and keeps its next round" do
        friend = create(:challenge_participant, challenge_story: story)
        check_in = create(:challenge_check_in, challenge_participant: participant, challenge_story: story)
        create(:challenge_check_in_reply, challenge_check_in: check_in, user: friend.user)
        create(:challenge_reward, giver: participant, receiver: friend, challenge_story: story)
        create(:badge, user: participant.user, challenge_story: story)
        next_round = story.next_round.tap(&:save!)

        delete admin_challenge_story_path(story)

        expect(response).to redirect_to(admin_root_path)
        expect(ChallengeStory.exists?(story.id)).to be false
        expect([ChallengeCheckIn, ChallengeCheckInReply, ChallengeReward, Badge].map(&:count)).to all(eq 0)
        expect(next_round.reload.previous_challenge_story_id).to be_nil
        expect(User.count).to eq 3
      end

      it "offers it in the challenge page's menu" do
        get challenge_story_path(story)

        expect(response.body).to include(admin_challenge_story_path(story))
      end
    end

    it "isn't offered to participants" do
      sign_in_as(participant.user)

      get challenge_story_path(story)

      expect(response.body).to include("Leave challenge")
      expect(response.body).not_to include(admin_challenge_story_path(story))
    end
  end
end
