class WebPushNotification < ApplicationRecord
  VAPID_SUBJECT = "https://#{Rails.configuration.app_host}"

  belongs_to :user

  def self.describe_device(user_agent)
    browser = case user_agent.to_s
    when /Firefox|FxiOS/ then "Firefox"
    when /Edg/ then "Edge"
    when /OPR|Opera/ then "Opera"
    when /SamsungBrowser/ then "Samsung Internet"
    when /Chrome|CriOS/ then "Chrome"
    when /Safari/ then "Safari"
    end

    platform = case user_agent.to_s
    when /iPhone/ then "iPhone"
    when /iPad/ then "iPad"
    when /Android/ then "Android"
    when /Macintosh|Mac OS X/ then "Mac"
    when /Windows/ then "Windows"
    when /Linux/ then "Linux"
    end

    [browser, platform].compact.join(" on ").presence
  end

  def label
    self.class.describe_device(user_agent) || device_name.presence || "Unknown device"
  end

  def send_notification(title:, body: nil, icon: nil, badge: nil, path: "/")
    message = JSON.generate({
      title: title,
      options: {
        body: body,
        icon: icon,
        badge: badge,
        data: {
          path: path
        }
      }.compact
    })

    ::WebPush.payload_send(
      message: message,
      endpoint: endpoint,
      p256dh: p256dh_key,
      auth: auth_key,
      vapid: {
        subject: VAPID_SUBJECT,
        private_key: Rails.application.credentials.dig(:web_push, :vapid_private_key),
        public_key: Rails.application.credentials.dig(:web_push, :vapid_public_key)
      }
    )
  rescue WebPush::ExpiredSubscription, WebPush::InvalidSubscription
    # Subscription expired or invalid, clean it up
    Rails.logger.info("Removing expired push subscription: #{id}")
    destroy
    nil
  end
end
