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

        it "labels the user's own check-ins as You" do
          get challenge_check_ins_path

          expect(response.body).to include(">You<")
        end

        it "renders check-ins with photos" do
          create(:challenge_check_in, :with_photo, challenge_participant: create(:challenge_participant, challenge_story: story))

          get challenge_check_ins_path

          expect(response.body).to include("Check-in photo")
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

      it "does not show check-ins from challenges the user left" do
        participant.leave!
        create(:challenge_check_in, challenge_participant: create(:challenge_participant, challenge_story: story), message: "After you left")

        get challenge_check_ins_path

        expect(response.body).not_to include("After you left")
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

      it "records the amount when the challenge counts something" do
        story.update!(unit: :km)

        post challenge_story_challenge_check_ins_path(story), params: {challenge_check_in: {message: "Morning run", amount: "5.2"}}

        expect(ChallengeCheckIn.last.amount).to eq BigDecimal("5.2")
        get challenge_story_path(story)
        expect(response.body).to include("5.2 km")
      end

      it "pre-fills the target and steps in whole reps" do
        story.update!(unit: :reps, target_amount: 50, target_scope: :each_period)

        get new_challenge_story_challenge_check_in_path(story)

        expect(response.body).to include('value="50"').and include('step="1"')
      end

      it "asks for the amount when it's missing" do
        story.update!(unit: :km)

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response).to have_http_status(:unprocessable_content)
        expect(response.body).to include("How many km?")
      end

      it "notifies the other participants" do
        friend = create(:challenge_participant, challenge_story: story)
        create(:web_push_notification, user: friend.user)

        expect {
          post challenge_story_challenge_check_ins_path(story), params: valid_params
        }.to have_enqueued_job(PushNotificationJob).exactly(:once)
      end

      it "celebrates new badges right away" do
        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(user.badges.first_check_in).to exist
        expect(response.body).to include("New badge")
        expect(response.body).to include("First step")
      end

      it "doesn't celebrate badges earned before" do
        create(:badge, user:)

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).not_to include("New badge")
      end

      it "keeps the sheet open to celebrate a new badge" do
        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).not_to include("data-close-sheet-after-value")
      end

      it "closes the sheet by itself when there's nothing new" do
        create(:badge, user:)
        create(:web_push_notification, user:)
        create(:challenge_check_in, challenge_participant: participant)

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).to include("data-close-sheet-after-value")
      end

      it "offers the progress card, which keeps a closing sheet open" do
        create(:badge, user:)
        create(:web_push_notification, user:)
        create(:challenge_check_in, challenge_participant: participant)

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).to include("Share my progress")
          .and include('data-action="share-card#share close-sheet#stay:stop"')
      end

      it "refreshes the progress card in the challenge page's menu, which doesn't reload" do
        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).to include(%(<turbo-stream action="replace" target="share_card_challenge_participant_#{participant.id}">))
          .and include(%(id="share_card_challenge_participant_#{participant.id}"))
      end

      it "asks to turn on notifications, naming friends, and stays open" do
        create(:badge, user:)
        create(:challenge_check_in, challenge_participant: participant)
        create(:challenge_participant, challenge_story: story, user: create(:user, username: "anna"))

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).to include("Hear when anna checks in")
        expect(response.body).not_to include("data-close-sheet-after-value")
      end

      it "doesn't ask once notifications are on" do
        create(:web_push_notification, user:)

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).not_to include("Hear when")
      end

      it "shows the streak" do
        create(:challenge_check_in, challenge_participant: participant, checked_in_on: Date.yesterday)

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).to include("2 days in a row")
      end

      it "shows the days to go for a streak freeze" do
        create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.yesterday)

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).to include("5 more days to earn a streak freeze")
      end

      it "celebrates a streak freeze on the 7th day in a row" do
        (1..6).each { create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.today - it) }

        post challenge_story_challenge_check_ins_path(story), params: valid_params

        expect(response.body).to include("Streak freeze earned")
        expect(response.body).not_to include("data-close-sheet-after-value")
      end
    end

    context "with invalid params" do
      let(:invalid_params) { {challenge_check_in: {message: ""}} }

      it "does not create a check-in" do
        expect do
          post challenge_story_challenge_check_ins_path(story), params: invalid_params
        end.not_to change(ChallengeCheckIn, :count)

        expect(response).to have_http_status(:unprocessable_content)
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

      it "posts another check-in without pinging friends again" do
        friend = create(:challenge_participant, challenge_story: story)
        create(:web_push_notification, user: friend.user)

        expect do
          post challenge_story_challenge_check_ins_path(story),
            params: {challenge_check_in: {message: "Another check-in"}}
        end.to change(ChallengeCheckIn, :count).by(1)

        expect(PushNotificationJob).not_to have_been_enqueued
      end
    end
  end

  describe "DELETE /challenge_stories/:challenge_story_id/challenge_check_ins/:id" do
    before { sign_in_as(user) }

    it "deletes your own check-in from today" do
      check_in = create(:challenge_check_in, challenge_participant: participant)

      expect {
        delete challenge_story_challenge_check_in_path(story, check_in)
      }.to change(ChallengeCheckIn, :count).by(-1)

      expect(response).to redirect_to(challenge_story_path(story))
      expect(participant.reload.challenge_check_ins_count).to eq 0
    end

    it "keeps check-ins from earlier days" do
      check_in = create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.yesterday)

      delete challenge_story_challenge_check_in_path(story, check_in)

      expect(response).to have_http_status(:forbidden)
      expect(ChallengeCheckIn.exists?(check_in.id)).to be true
    end

    it "doesn't let you delete a friend's check-in" do
      check_in = create(:challenge_check_in, challenge_participant: create(:challenge_participant, challenge_story: story))

      delete challenge_story_challenge_check_in_path(story, check_in)

      expect(response).to have_http_status(:not_found)
      expect(ChallengeCheckIn.exists?(check_in.id)).to be true
    end
  end
end
