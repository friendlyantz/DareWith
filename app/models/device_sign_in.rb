# frozen_string_literal: true

# A new device asking to be signed in; a device that's already signed in approves it by its code
class DeviceSignIn < ApplicationRecord
  CODE_LENGTH = 6
  CODE_CHARACTERS = "ABCDEFGHJKLMNPQRSTUVWXYZ23456789".chars.freeze
  LIFETIME = 5.minutes

  belongs_to :user, optional: true

  enum :state, %w[pending approved used].index_by(&:itself)

  normalizes :code, with: ->(code) { code.upcase.gsub(/[^A-Z0-9]/, "") }

  validates :code, :expires_at, presence: true

  scope :live, -> { where(expires_at: Time.current..) }
  scope :stale, -> { where(expires_at: ...1.day.ago) }

  before_validation on: :create do
    self.code ||= SecureRandom.alphanumeric(CODE_LENGTH, chars: CODE_CHARACTERS)
    self.expires_at ||= LIFETIME.from_now
  end

  def self.find_pending(code)
    pending.live.find_by(code: normalize_value_for(:code, code.to_s))
  end

  def expired?
    expires_at.past?
  end

  def device_label
    WebPushNotification.describe_device(user_agent) || "a new device"
  end

  # The waiting device refreshes and signs itself in
  def approve!(approver)
    update!(user: approver, state: :approved)
    Turbo::StreamsChannel.broadcast_refresh_to(self)
  end

  # Returns the user once, so the same approval can't sign in two browsers
  def claim!
    return unless approved? && !expired?

    user if self.class.approved.where(id:).update_all(state: "used", updated_at: Time.current) == 1
  end
end
