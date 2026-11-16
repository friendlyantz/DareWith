class TodayController < ApplicationController
  before_action :require_current_user!

  def show
    @challenge_stories, @wrap_up_stories = current_user.active_challenge_stories
      .includes(active_participants: [:user, :todays_check_ins])
      .order(:finish)
      .partition(&:accepting_check_ins?)

    @checked_in_count = @challenge_stories.count { it.participant_for(current_user).checked_in_today? }
  end
end
