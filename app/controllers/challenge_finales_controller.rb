class ChallengeFinalesController < ApplicationController
  def show
    @challenge_story = ChallengeStory
      .includes(
        active_participants: [{user: {avatar_attachment: :blob}}, :check_in_days],
        challenge_check_ins: [{challenge_participant: {user: {avatar_attachment: :blob}}}, photo_attachment: :blob]
      )
      .find(params[:challenge_story_id])
    return redirect_to @challenge_story unless @challenge_story.finished?

    @finale = @challenge_story.finale
    @current_challenge_participant = @challenge_story.participant_for(current_user) if current_user
  end
end
