require "rails_helper"

RSpec.describe "ChallengeCheckIns", type: :request do
  let(:user) { create(:user) }
  let(:story) { create(:challenge_story) }
  let!(:participant) { create(:challenge_participant, user: user, challenge_story: story) }

  describe "GET /challenge_check_ins" do
    context "when not signed in" do
      it "redirects to sign in" do
        get challenge_check_ins_path

        expect(response).to redirect_to(new_webauthn_session_path)
      end
    end

    context "when signed in" do
      before { sign_in_as(user) }

      context "with check-ins from user's challenges" do
        let!(:check_in) { create(:challenge_check_in, challenge_participant: participant, challenge_story: story) }

        it "returns check-in feed" do
          get challenge_check_ins_path

          expect(response).to have_http_status(:ok)
          expect(response.body).to include(check_in.message)
        end

        it "includes challenge context" do
          get challenge_check_ins_path

          expect(response.body).to include(story.title)
        end
      end

      context "with check-ins from other participants in the same challenge" do
        let(:other_user) { create(:user) }
        let!(:other_participant) { create(:challenge_participant, user: other_user, challenge_story: story) }
        let!(:other_check_in) do
          create(:challenge_check_in, challenge_participant: other_participant, challenge_story: story)
        end

        it "shows check-ins from other participants in user's challenges" do
          get challenge_check_ins_path

          expect(response.body).to include(other_check_in.message)
        end
      end

      context "with check-ins from other user's challenges" do
        let(:other_user) { create(:user) }
        let(:other_story) { create(:challenge_story) }
        let(:other_participant) { create(:challenge_participant, user: other_user, challenge_story: other_story) }
        let!(:other_check_in) do
          create(:challenge_check_in, challenge_participant: other_participant, challenge_story: other_story)
        end

        it "does not show check-ins from challenges user doesn't participate in" do
          get challenge_check_ins_path

          expect(response.body).not_to include(other_check_in.message)
        end
      end
    end
  end

  describe "GET /challenge_stories/:challenge_story_id/challenge_check_ins/new" do
    context "when not signed in" do
      it "redirects to sign in" do
        get new_challenge_story_challenge_check_in_path(story)

        expect(response).to redirect_to(new_webauthn_session_path)
      end
    end

    context "when signed in but not a participant" do
      let(:other_user) { create(:user) }

      before { sign_in_as(other_user) }

      it "redirects with alert" do
        get new_challenge_story_challenge_check_in_path(story)

        expect(response).to redirect_to(challenge_story_path(story))
        expect(flash[:alert]).to include("participant")
      end
    end

    context "when signed in as a participant" do
      before { sign_in_as(user) }

      it "returns the new check-in form" do
        get new_challenge_story_challenge_check_in_path(story)

        expect(response).to have_http_status(:ok)
      end
    end
  end

  describe "POST /challenge_stories/:challenge_story_id/challenge_check_ins" do
    before { sign_in_as(user) }

    context "with valid params" do
      let(:valid_params) { {challenge_check_in: {message: "Today's check-in!"}} }

      it "creates a new check-in" do
        expect do
          post challenge_story_challenge_check_ins_path(story), params: valid_params
        end.to change(ChallengeCheckIn, :count).by(1)

        expect(response).to have_http_status(:ok)
      end
    end

    context "with invalid params" do
      let(:invalid_params) { {challenge_check_in: {message: ""}} }

      it "does not create a check-in" do
        expect do
          post challenge_story_challenge_check_ins_path(story), params: invalid_params
        end.not_to change(ChallengeCheckIn, :count)

        expect(response).to have_http_status(:unprocessable_entity)
      end
    end

    context "when story is completed" do
      before { story.update!(completed: true) }

      it "redirects with alert" do
        post challenge_story_challenge_check_ins_path(story), params: {challenge_check_in: {message: "Test"}}

        expect(response).to redirect_to(challenge_story_path(story))
        expect(flash[:alert]).to include("completed")
      end
    end

    context "when already checked in today" do
      before do
        create(:challenge_check_in, challenge_participant: participant, challenge_story: story)
      end

      it "does not allow duplicate check-in" do
        expect do
          post challenge_story_challenge_check_ins_path(story),
            params: {challenge_check_in: {message: "Another check-in"}}
        end.not_to change(ChallengeCheckIn, :count)
      end
    end
  end
end
