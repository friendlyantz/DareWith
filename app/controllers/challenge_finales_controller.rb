class ChallengeFinalesController < ApplicationController
  def show
    @challenge_story = ChallengeStory
      .includes(
        active_participants: [{user: {avatar_attachment: :blob}}, :check_in_days],
        challenge_rewards: {giver: {user: {avatar_attachment: :blob}}},
        challenge_check_ins: [{challenge_participant: {user: {avatar_attachment: :blob}}}, :challenge_check_in_likes, :challenge_check_in_replies, photo_attachment: :blob]
      )
      .find_by(id: params[:challenge_story_id])
    return redirect_to root_path, alert: "That challenge no longer exists" unless @challenge_story
    return redirect_to @challenge_story unless @challenge_story.finished?

    @finale = @challenge_story.finale
    @current_challenge_participant = @challenge_story.participant_for(current_user) if current_user
  end
end
