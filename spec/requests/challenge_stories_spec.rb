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

    it "sends you home when the challenge was deleted, e.g. from an old alert" do
      get challenge_story_path(id: SecureRandom.uuid)

      expect(response).to redirect_to(root_path)
      expect(flash[:alert]).to eq("That challenge no longer exists")
    end

    it "counts down to the start instead of offering a check-in" do
      story.update!(start: Time.zone.today + 3.days, finish: Time.zone.today + 10.days)
      user = create(:user)
      create(:challenge_participant, user:, challenge_story: story)
      sign_in_as(user)

      get challenge_story_path(story)

      expect(response.body).to include("Starts in 3 days · #{story.start.strftime("%a %-d %b")}")
      expect(response.body).not_to include("btn btn-primary btn-lg btn-block")
    end

    it "shows totals and your pace for a target by the end" do
      story.update!(start: Time.zone.today - 1.day, finish: Time.zone.today + 28.days, unit: :km, target_amount: 100, target_scope: :total)
      user = create(:user)
      participant = create(:challenge_participant, user:, challenge_story: story)
      create(:challenge_check_in, challenge_participant: participant, amount: 10)
      create(:challenge_participant, challenge_story: story)
      sign_in_as(user)

      get challenge_story_path(story)

      expect(response.body).to include("10/100").and include("aiming for 100 km each")
      expect(response.body).to include("At this pace: 100 km by #{(story.start + 19.days).strftime("%-d %b")}")
    end

    it "marks friends who have notifications off on the leaderboard" do
      user = create(:user)
      create(:challenge_participant, user:, challenge_story: story)
      create(:challenge_participant, challenge_story: story)
      create(:web_push_notification, user: create(:challenge_participant, challenge_story: story).user)
      sign_in_as(user)

      get challenge_story_path(story)

      expect(response.body.scan('aria-label="Notifications off"').size).to eq 1
    end

    describe "alone in a challenge" do
      before do
        user = create(:user)
        create(:challenge_participant, user:, challenge_story: story)
        sign_in_as(user)
      end

      it "skips the race wording on the leaderboard" do
        get challenge_story_path(story)

        expect(response.body).to include("Invite friends to make it a race")
        expect(response.body).not_to include("so far</p>")
      end

      it "only says to invite someone on the rewards tab" do
        get challenge_story_path(story)

        expect(response.body).to include("Invite someone to unlock reward pledging")
        expect(response.body).not_to include("Pledge one to raise the stakes")
      end
    end

    describe "inviting friends" do
      let(:user) { create(:user) }

      before { create(:challenge_participant, user:, challenge_story: story) }

      it "shows an invite card and empty spots to someone alone in a challenge" do
        sign_in_as(user)
        get challenge_story_path(story)

        expect(response.body).to include("Invite your friends").and include("Invite friends, 3 spots left")
      end

      it "drops the card once a friend joins, but keeps the empty spots" do
        create(:challenge_participant, challenge_story: story)
        sign_in_as(user)
        get challenge_story_path(story)

        expect(response.body).not_to include("Invite your friends")
        expect(response.body).to include("Invite friends, 2 spots left")
      end

      it "doesn't invite when the challenge is full" do
        create_list(:challenge_participant, 3, challenge_story: story)
        sign_in_as(user)
        get challenge_story_path(story)

        expect(response.body).not_to include("Invite friends")
      end

      it "doesn't invite visitors" do
        get challenge_story_path(story)

        expect(response.body).not_to include("Invite friends")
        expect(response.body).not_to include("Invite your friends")
      end
    end

    it "offers participants a progress card to share, but not visitors" do
      user = create(:user)
      create(:challenge_participant, user:, challenge_story: story)

      get challenge_story_path(story)
      expect(response.body).not_to include("Share my progress")

      sign_in_as(user)
      get challenge_story_path(story)
      expect(response.body).to include("Share my progress").and include('data-controller="share-card"')
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
        expect(response.body).to include("30 days of push-ups")
      end

      it "pre-fills the form from a template" do
        get new_challenge_story_path(template: "run")

        expect(response.body).to include('value="Run 3× a week"')
        expect(response.body).to include('<option selected="selected" value="weekly">')
        expect(response.body).to include("Start blank")
      end

      it "shows a blank form for an unknown template" do
        get new_challenge_story_path(template: "nope")

        expect(response).to have_http_status(:ok)
        expect(response.body).not_to include("Start blank")
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
        post challenge_stories_path, params: {challenge_story: valid_params[:challenge_story].merge(unit: "reps", target_amount: "50", target_scope: "each_period")}

        expect(ChallengeStory.last).to have_attributes(unit: "reps", target_amount: 50, target_scope: "each_period")
        follow_redirect!
        expect(response.body).to include("50 reps a day")
      end

      it "saves a penalty and shows it as a rule" do
        post challenge_stories_path, params: {challenge_story: valid_params[:challenge_story].merge(penalty_mode: "per_miss", penalty: " a coffee ")}

        expect(ChallengeStory.last).to have_attributes(penalty_mode: "per_miss", penalty: "a coffee")
        follow_redirect!
        expect(response.body).to include("Each miss: owe everyone a coffee")
      end

      it "drops the penalty when nothing happens on a miss" do
        post challenge_stories_path, params: {challenge_story: valid_params[:challenge_story].merge(penalty_mode: "", penalty: "a coffee")}

        expect(ChallengeStory.last.penalty).to be_nil
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

    it "changes the dates once the goal is locked" do
      story = create(:challenge_story, unit: :reps, target_amount: 50, target_scope: :each_period)
      participant = create(:challenge_participant, user:, challenge_story: story)
      create(:challenge_check_in, challenge_participant: participant, amount: 50)
      new_finish = story.finish + 1.day

      # The goal fieldset is disabled, so the form only sends the other fields
      patch challenge_story_path(story), params: {challenge_story: {title: story.title, description: story.description, start: story.start, finish: new_finish}}

      expect(response).to redirect_to(story)
      expect(story.reload.finish).to eq new_finish
    end

    it "tells friends when the end moves" do
      story = create(:challenge_story)
      new_finish = story.finish + 6.days
      create(:challenge_participant, user:, challenge_story: story)
      friend_device = create(:web_push_notification, user: create(:challenge_participant, challenge_story: story).user)

      expect { patch challenge_story_path(story), params: {challenge_story: {finish: new_finish}} }
        .to have_enqueued_job(PushNotificationJob).with(friend_device, hash_including(title: "#{user.username} changed #{story.title}", body: "Ends #{new_finish.strftime("%-d %b")}"))
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

    it "starts the prefilled round today, as long as the previous one" do
      get new_challenge_story_path(previous_challenge_story_id: round_one.id)

      expect(response.body).to match(/value="#{Time.zone.today.iso8601}"[^>]*name="challenge_story\[start\]"/)
      expect(response.body).to match(/value="#{(Time.zone.today + (round_one.duration_in_days - 1).days).iso8601}"[^>]*name="challenge_story\[finish\]"/)
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
