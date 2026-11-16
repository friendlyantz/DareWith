class CheckInReminderJob < ApplicationJob
  def perform
    User.where.not(reminder_hour: nil).where(id: WebPushNotification.select(:user_id)).find_each do |user|
      user.remind_to_check_in
    rescue => err
      Rails.error.report(err, handled: true)
    end
  end
end
