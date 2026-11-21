class NotificationsController < ApplicationController
  before_action :require_current_user!

  def index
    @notifications = current_user.notifications.recent.to_a
    current_user.read_notifications!
  end
end
