# frozen_string_literal: true

# Everything sent through User#notify, kept so people without push still see it in the app
class Notification < ApplicationRecord
  SHOWN = 50

  # Associations
  belongs_to :user

  # Validations
  validates :title, presence: true

  # Scopes
  scope :unread, -> { where(read_at: nil) }
  scope :recent, -> { order(created_at: :desc).limit(SHOWN) }

  # Callbacks
  after_create_commit -> { broadcast_replace_later_to user, "notifications", target: "notifications_badge", partial: "notifications/badge", locals: {user:} }

  # Public methods
  def unread?
    read_at.nil?
  end
end
