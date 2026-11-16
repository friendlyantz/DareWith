class WebPushNotificationsController < ApplicationController
  def create
    return head :unauthorized unless current_user

    subscription = JSON.parse(request.body.read)

    WebPushNotification.where(endpoint: subscription["endpoint"]).where.not(user: current_user).destroy_all

    notification = current_user.web_push_notifications.find_or_initialize_by(endpoint: subscription["endpoint"])
    notification.update!(
      auth_key: subscription.dig("keys", "auth"),
      p256dh_key: subscription.dig("keys", "p256dh"),
      device_name: WebPushNotification.describe_device(request.user_agent),
      user_agent: request.user_agent
    )

    render json: {success: true, id: notification.id}, status: :created
  end

  def unsubscribe
    return head :unauthorized unless current_user

    # Find subscription by endpoint from request body
    subscription = JSON.parse(request.body.read)
    endpoint = subscription["endpoint"]

    notification = current_user.web_push_notifications.find_by(endpoint: endpoint)
    notification&.destroy

    head :ok
  end

  def destroy
    return head :unauthorized unless current_user

    current_user.web_push_notifications.find(params[:id]).destroy
    cookies[:push_notification_dismissed] = {value: "true", expires: 1.year}
    redirect_to profile_path, notice: "That device won't get notifications any more"
  end
end
