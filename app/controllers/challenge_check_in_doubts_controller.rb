class ChallengeCheckInDoubtsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :require_current_user!
  before_action :set_challenge_check_in

  def create
    return head :forbidden unless @challenge_check_in.doubtable_by?(current_user)

    @challenge_check_in.doubt!(current_user, note: params.dig(:challenge_check_in_doubt, :note)).notify_author
    redirect_back_or_to challenge_story_path(@challenge_check_in.challenge_story, anchor: dom_id(@challenge_check_in)), notice: "You doubted this check-in."
  end

  def destroy
    return head :forbidden unless @challenge_check_in.doubtable_by?(current_user)

    @challenge_check_in.withdraw_doubt!(current_user)
    redirect_back_or_to challenge_story_path(@challenge_check_in.challenge_story, anchor: dom_id(@challenge_check_in)), notice: "Doubt withdrawn.", status: :see_other
  end

  private

  def set_challenge_check_in
    @challenge_check_in = ChallengeCheckIn.find(params[:challenge_check_in_id])
  end
end
