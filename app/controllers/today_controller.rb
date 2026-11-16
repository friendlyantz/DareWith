class TodayController < ApplicationController
  before_action :require_current_user!

  def show
    @challenge_stories = current_user.active_challenge_stories
      .includes(active_participants: [:user, :todays_check_ins])
      .order(:finish)

    @checked_in_count = @challenge_stories.count { it.participant_for(current_user).checked_in_today? }
  end
end
