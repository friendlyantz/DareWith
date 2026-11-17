class ChallengeNudgesController < ApplicationController
  before_action :require_current_user!

  def create
    receiver = ChallengeParticipant.active.find(params[:challenge_participant_id])
    sender = current_user.challenge_participants.active.find_by!(challenge_story_id: receiver.challenge_story_id)
    @challenge_nudge = ChallengeNudge.new(sender:, receiver:)
    return head :unprocessable_content unless @challenge_nudge.save

    @challenge_nudge.deliver
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_back_or_to challenge_story_path(receiver.challenge_story), notice: "You nudged #{receiver.name}." }
    end
  end
end
