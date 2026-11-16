class Admin::NotificationsController < Admin::ApplicationController
  def create
    user = User.find(params[:user_id])
    return redirect_to admin_user_path(user), alert: "#{user.username} has no push devices" if user.web_push_notifications.none?
    return redirect_to admin_user_path(user), alert: "Add a title" if notification_params[:title].blank?

    user.notify(title: notification_params[:title], body: notification_params[:body].presence, path: "/today")
    redirect_to admin_user_path(user), notice: "Push sent to #{helpers.pluralize(user.web_push_notifications.size, "device")}"
  end

  private

  def notification_params
    params.expect(notification: [:title, :body])
  end
end
