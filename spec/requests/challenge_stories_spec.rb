require "rails_helper"

RSpec.describe "ChallengeStories", type: :request do
  describe "GET /challenge_stories" do
    context "when not signed in" do
      it "returns empty stories" do
        get challenge_stories_path

        expect(response).to have_http_status(:ok)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "returns user's challenge stories" do
        story = create(:challenge_story)
        create(:challenge_participant, user: user, challenge_story: story)

        get challenge_stories_path

        expect(response).to have_http_status(:ok)
        expect(response.body).to include(story.title)
      end
    end
  end

  describe "GET /challenge_stories/:id" do
    let(:story) { create(:challenge_story) }

    it "returns the challenge story" do
      get challenge_story_path(story)

      expect(response).to have_http_status(:ok)
      expect(response.body).to include(story.title)
    end
  end

  describe "GET /challenge_stories/new" do
    context "when not signed in" do
      it "redirects to sign in" do
        get new_challenge_story_path

        expect(response).to redirect_to(new_webauthn_session_path)
      end
    end

    context "when signed in" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "returns new form" do
        get new_challenge_story_path

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /challenge_stories" do
    let(:user) { create(:user) }

    before { sign_in_as(user) }

    context "with valid params" do
      let(:valid_params) do
        {
          challenge_story: {
            title: "New Challenge",
            description: "Test description",
            start: Time.zone.today,
            finish: Time.zone.today + 7.days
          }
        }
      end

      it "creates a new challenge story" do
        expect {
          post challenge_stories_path, params: valid_params
        }.to change(ChallengeStory, :count).by(1)

        expect(response).to redirect_to(challenge_story_path(ChallengeStory.last))
      end

      it "adds the creator as a participant" do
        post challenge_stories_path, params: valid_params

        story = ChallengeStory.last
        expect(story.challenge_participants.exists?(user: user)).to be true
      end
    end

    context "with invalid params" do
      let(:invalid_params) do
        {
          challenge_story: {
            title: "",
            description: "Test",
            start: Time.zone.today,
            finish: Time.zone.today - 1.day
          }
        }
      end

      it "does not create a challenge story" do
        expect {
          post challenge_stories_path, params: invalid_params
        }.not_to change(ChallengeStory, :count)

        expect(response).to have_http_status(:unprocessable_content)
      end
    end
  end

  describe "PATCH /challenge_stories/:id/complete" do
    let(:user) { create(:user) }
    let(:story) { create(:challenge_story) }

    before { sign_in_as(user) }

    it "marks the story as complete" do
      create(:challenge_participant, user: user, challenge_story: story)

      patch complete_challenge_story_path(story)

      expect(story.reload).to be_completed
      expect(response).to redirect_to(challenge_story_path(story))
    end

    it "lets the other participants know" do
      create(:challenge_participant, user: user, challenge_story: story)
      friend = create(:challenge_participant, challenge_story: story)
      device = create(:web_push_notification, user: friend.user)
      create(:web_push_notification, user: user)

      expect {
        patch complete_challenge_story_path(story)
      }.to have_enqueued_job(PushNotificationJob).with(device, hash_including(title: "#{story.title} is complete")).exactly(:once)
    end

    it "does not let non-participants complete it" do
      patch complete_challenge_story_path(story)

      expect(response).to have_http_status(:not_found)
      expect(story.reload).not_to be_completed
    end
  end

  describe "PATCH /challenge_stories/:id" do
    let(:user) { create(:user) }
    let(:story) { create(:challenge_story, title: "Original") }

    before { sign_in_as(user) }

    it "does not let non-participants edit it" do
      patch challenge_story_path(story), params: {challenge_story: {title: "Hijacked"}}

      expect(response).to have_http_status(:not_found)
      expect(story.reload.title).to eq("Original")
    end
  end

  describe "DELETE /challenge_stories/:id" do
    let(:user) { create(:user) }
    let!(:story) { create(:challenge_story) }

    before { sign_in_as(user) }

    it "destroys the challenge story" do
      create(:challenge_participant, user: user, challenge_story: story)

      expect {
        delete challenge_story_path(story)
      }.to change(ChallengeStory, :count).by(-1)

      expect(response).to redirect_to(challenge_stories_path)
    end
  end
end
