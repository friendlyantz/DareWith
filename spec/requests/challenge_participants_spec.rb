require "rails_helper"

RSpec.describe "ChallengeParticipants", type: :request do
  let(:user) { create(:user) }
  let(:story) { create(:challenge_story) }

  describe "POST /challenge_participants" do
    context "when not signed in" do
      it "redirects to sign up" do
        post challenge_participants_path, params: {challenge_story_id: story.id}

        expect(response).to redirect_to(new_webauthn_registration_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      it "creates a new participant" do
        expect {
          post challenge_participants_path, params: {challenge_story_id: story.id}
        }.to change(ChallengeParticipant, :count).by(1)
      end

      it "returns to the challenge with a welcome notice" do
        post challenge_participants_path, params: {challenge_story_id: story.id}

        expect(response).to redirect_to(challenge_story_path(story))
        expect(flash[:notice]).to include("You've joined!")
      end

      it "tells existing participants someone joined" do
        existing = create(:challenge_participant, challenge_story: story)
        create(:web_push_notification, user: existing.user)

        expect {
          post challenge_participants_path, params: {challenge_story_id: story.id}
        }.to have_enqueued_job(PushNotificationJob).exactly(:once)
      end

      it "does not announce again when already a participant" do
        create(:challenge_participant, user: user, challenge_story: story)
        create(:web_push_notification, user: create(:challenge_participant, challenge_story: story).user)

        expect {
          post challenge_participants_path, params: {challenge_story_id: story.id}
        }.not_to have_enqueued_job(PushNotificationJob)
      end

      it "associates the participant with the user" do
        post challenge_participants_path, params: {challenge_story_id: story.id}

        participant = ChallengeParticipant.last
        expect(participant.user).to eq(user)
        expect(participant.challenge_story).to eq(story)
      end

      context "when story is at capacity" do
        before do
          ChallengeStory::MAX_PARTICIPANTS.times do
            create(:challenge_participant, challenge_story: story)
          end
        end

        it "redirects with alert" do
          post challenge_participants_path, params: {challenge_story_id: story.id}

          expect(response).to redirect_to(challenge_story_path(story))
          expect(flash[:alert]).to include("full")
        end
      end
    end
  end

  describe "DELETE /challenge_participants/:id" do
    let!(:participant) { create(:challenge_participant, user: user, challenge_story: story) }

    before { sign_in_as(user) }

    it "marks the participant as inactive" do
      delete challenge_participant_path(participant)

      expect(participant.reload).to be_inactive
      expect(response).to redirect_to(challenge_story_path(story))
    end

    it "does not let a user remove someone else" do
      other = create(:challenge_participant, challenge_story: story)

      delete challenge_participant_path(other)

      expect(response).to have_http_status(:not_found)
      expect(other.reload).to be_active
    end
  end
end
