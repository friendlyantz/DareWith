class ProfilesController < ApplicationController
  before_action :require_current_user!

  def show
    running, @wrap_up_stories = current_user.active_challenge_stories.order(finish: :desc).partition(&:accepting_check_ins?)
    @active_challenges_count = running.size
    @past_challenge_stories = current_user.past_challenge_stories.order(finish: :desc)
    @push_devices = current_user.web_push_notifications.order(:created_at)
  end

  def update
    if current_user.update(profile_params)
      redirect_to profile_path, notice: update_notice
    else
      redirect_to profile_path, alert: current_user.errors.full_messages.to_sentence
    end
  end

  private

  def profile_params
    params.expect(user: [:reminder_hour, :payment_details])
  end

  def update_notice
    return "Payment details saved" if profile_params.key?(:payment_details)

    current_user.reminder_hour ? "Reminder set for #{format("%02d:00", current_user.reminder_hour)}" : "Reminder turned off"
  end
end
