class TodayController < ApplicationController
  before_action :require_current_user!

  def show
    @challenge_stories, @wrap_up_stories = current_user.active_challenge_stories
      .includes(active_participants: [{user: {avatar_attachment: :blob}}, :todays_check_ins, :check_in_days])
      .order(:finish)
      .partition(&:accepting_check_ins?)

    @done_count = @challenge_stories.count { it.participant_for(current_user).done_for_now? }
    @round_invites = current_user.next_round_invites
  end
end
