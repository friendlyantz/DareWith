class WeeklyRecapJob < ApplicationJob
  def perform
    User.where(id: WebPushNotification.select(:user_id)).find_each do |user|
      user.send_weekly_recap
    rescue => err
      Rails.error.report(err, handled: true)
    end
  end
end
