class ChallengeCheckInRepliesController < ApplicationController
  before_action :require_current_user!
  before_action :set_challenge_check_in

  def create
    @challenge_check_in_reply = @challenge_check_in.challenge_check_in_replies.build(reply_params.merge(user: current_user))
    return head :unprocessable_content unless @challenge_check_in_reply.save

    @challenge_check_in_reply.notify_thread
    respond_to do |format|
      format.turbo_stream
      format.html { redirect_to challenge_story_path(@challenge_check_in.challenge_story, anchor: helpers.dom_id(@challenge_check_in)) }
    end
  end

  private

  # Only participants of the challenge can reply
  def set_challenge_check_in
    @challenge_check_in = ChallengeCheckIn
      .where(challenge_story_id: current_user.challenge_participants.active.select(:challenge_story_id))
      .find(params[:challenge_check_in_id])
  end

  def reply_params
    params.expect(challenge_check_in_reply: [:body])
  end
end
