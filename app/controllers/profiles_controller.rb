class ProfilesController < ApplicationController
  before_action :require_current_user!

  def show
    @active_challenges_count = current_user.active_challenge_stories.count
    @past_challenge_stories = current_user.past_challenge_stories.order(finish: :desc)
  end

  def update
    current_user.update!(profile_params)
    redirect_to profile_path, notice: current_user.reminder_hour ? "Reminder set for #{format("%02d:00", current_user.reminder_hour)}" : "Reminder turned off"
  end

  private

  def profile_params
    params.expect(user: [:reminder_hour])
  end
end
