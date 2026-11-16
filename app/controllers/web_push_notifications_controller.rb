class WebPushNotificationsController < ApplicationController
  def create
    return head :unauthorized unless current_user

    subscription = JSON.parse(request.body.read)

    WebPushNotification.where(endpoint: subscription["endpoint"]).where.not(user: current_user).destroy_all

    notification = current_user.web_push_notifications.find_or_initialize_by(endpoint: subscription["endpoint"])
    notification.update!(
      auth_key: subscription.dig("keys", "auth"),
      p256dh_key: subscription.dig("keys", "p256dh"),
      device_name: detect_device_name,
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

  private

  def detect_device_name
    ua = request.user_agent.to_s.downcase

    # Mobile devices first
    return "iPhone" if ua.include?("iphone")
    return "iPad" if ua.include?("ipad")
    return "Android Phone" if ua.include?("android") && ua.include?("mobile")
    return "Android Tablet" if ua.include?("android")

    # Desktop browsers (order matters - check specific before generic)
    return "Chrome Desktop" if ua.include?("chrome")
    return "Brave Desktop" if ua.include?("brave")
    return "Firefox Desktop" if ua.include?("firefox")
    return "Safari Desktop" if ua.include?("safari") && !ua.include?("chrome")
    return "Edge Desktop" if ua.include?("edg")
    return "Arc Desktop" if ua.include?("arc")
    return "Opera Desktop" if ua.include?("opr") || ua.include?("opera")
    return "Vivaldi Desktop" if ua.include?("vivaldi")
    return "Tor Browser" if ua.include?("tor")

    "Unknown Device"
  end
end
