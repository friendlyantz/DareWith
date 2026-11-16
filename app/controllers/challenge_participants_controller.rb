class ChallengeParticipantsController < ApplicationController
  before_action :require_current_user!
  before_action :set_challenge_story, only: [:create]

  def create
    return redirect_to challenge_story_path(@challenge_story), alert: "This challenge is full (max #{ChallengeStory::MAX_PARTICIPANTS} participants)" if @challenge_story.at_capacity?

    joining = @challenge_story.participant_for(current_user).nil?
    participant = @challenge_story.find_or_activate_participant!(current_user)
    participant.announce_joining if joining

    redirect_to challenge_story_path(@challenge_story), notice: "You've joined! Welcome to the challenge."
  end

  def destroy
    challenge_participant = current_user.challenge_participants.find(params[:id])
    challenge_participant.leave!
    redirect_to challenge_story_path(challenge_participant.challenge_story), notice: "You have left the challenge!"
  end

  private

  def set_challenge_story
    @challenge_story = ChallengeStory.find(params[:challenge_story_id])
  end
end
