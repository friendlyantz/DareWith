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

      it "saves the goal" do
        post challenge_stories_path, params: {challenge_story: valid_params[:challenge_story].merge(unit: "reps", target_amount: "50", target_scope: "each_time")}

        expect(ChallengeStory.last).to have_attributes(unit: "reps", target_amount: 50, target_scope: "each_time")
        follow_redirect!
        expect(response.body).to include("50 reps each time")
      end

      it "creates a weekly challenge" do
        post challenge_stories_path, params: {challenge_story: valid_params[:challenge_story].merge(cadence: "weekly", times_per_period: "3", finish: Time.zone.today + 27.days)}

        expect(ChallengeStory.last).to have_attributes(cadence: "weekly", times_per_period: 3)
        follow_redirect!
        expect(response.body).to include("Week 1 of 4").and include("3× a week")
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

  describe "GET /challenge_stories/:id/edit" do
    let(:story) { create(:challenge_story) }

    context "when not signed in" do
      it "redirects to sign in" do
        get edit_challenge_story_path(story)

        expect(response).to redirect_to(new_webauthn_session_path)
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

  describe "next rounds" do
    let(:user) { create(:user) }
    let(:round_one) { create(:challenge_story, :finished, title: "Gym") }
    let(:params) do
      {previous_challenge_story_id: round_one.id, challenge_story: {title: "Gym", description: "Again", start: Time.zone.today, finish: Time.zone.today + 6.days}}
    end

    before do
      create(:challenge_participant, user:, challenge_story: round_one)
      sign_in_as(user)
    end

    it "offers the next round on a finished challenge" do
      get challenge_story_path(round_one)

      expect(response.body).to include("Start round 2")
      expect(response.body).to include(new_challenge_story_path(previous_challenge_story_id: round_one.id))
    end

    it "prefills the form from the previous round" do
      get new_challenge_story_path(previous_challenge_story_id: round_one.id)

      expect(response.body).to include("Round 2")
      expect(response.body).to include('value="Gym"')
      expect(response.body).to match(/name="previous_challenge_story_id"[^>]*value="#{round_one.id}"/)
    end

    it "starts the next round and invites the others" do
      friend = create(:challenge_participant, challenge_story: round_one)
      create(:web_push_notification, user: friend.user)

      expect { post challenge_stories_path, params: }
        .to change(ChallengeStory, :count).by(1)
        .and have_enqueued_job(PushNotificationJob).exactly(:once)

      round_two = round_one.reload.next_challenge_story
      expect(round_two.round).to eq 2
      expect(round_two.active_participants.map(&:user)).to eq [user]
      expect(response).to redirect_to(round_two)
    end

    it "sends everyone to the round that already started" do
      round_two = round_one.next_round.tap(&:save!)

      expect { post challenge_stories_path, params: }.not_to change(ChallengeStory, :count)
      expect(response).to redirect_to(round_two)

      get challenge_story_path(round_one)
      expect(response.body).to include("Round 2 is on")
    end

    it "doesn't link a challenge the user wasn't in" do
      stranger_story = create(:challenge_story, :finished)

      get new_challenge_story_path(previous_challenge_story_id: stranger_story.id)

      expect(response).to have_http_status(:not_found)
    end
  end
end
