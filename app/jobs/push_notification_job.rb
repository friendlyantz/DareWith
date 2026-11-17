class PushNotificationJob < ApplicationJob
  retry_on WebPush::ResponseError, wait: :polynomially_longer, attempts: 3
  discard_on ActiveJob::DeserializationError

  def perform(subscription, title:, body: nil, path: "/")
    subscription.send_notification(title:, body:, path:, icon: "/icons/icon-192.png", badge: "/icons/badge-96.png")
  end
end
