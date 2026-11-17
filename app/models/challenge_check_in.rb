# frozen_string_literal: true

class ChallengeCheckIn < ApplicationRecord
  # Associations
  belongs_to :challenge_participant, counter_cache: true
  belongs_to :challenge_story, counter_cache: true
  has_one_attached :photo
  has_many :challenge_check_in_likes, dependent: :destroy
  has_many :liking_users, through: :challenge_check_in_likes, source: :user
  has_many :challenge_check_in_replies, -> { order(:created_at) }, dependent: :destroy

  # Validations
  validates :message, presence: true
  validates :amount, presence: true, numericality: {greater_than: 0, less_than: 100_000_000}, if: -> { challenge_story&.goal&.measured? }
  validates :amount, numericality: {only_integer: true, message: "must be a whole number"}, allow_nil: true, if: -> { challenge_story&.goal&.whole_numbers? }
  validate :photo_size_validation

  # Scopes
  scope :today, -> { where(checked_in_on: Time.zone.today) }

  # Callbacks
  before_validation on: :create do
    self.checked_in_on ||= (created_at || Time.current).in_time_zone.to_date
  end

  before_validation do
    self.amount = nil unless challenge_story&.goal&.measured?
  end

  # Broadcasts must be after has_one_attached for Cloudinary compatibility)
  after_create_commit :broadcast_to_story_and_participant_feeds
  after_destroy_commit :remove_from_story_and_participant_feeds

  # Public methods
  def first_of_the_day?
    !ChallengeCheckIn.where(challenge_participant_id:, checked_in_on:).where.not(id:).exists?
  end

  # Mistakes are fixed by deleting and posting again, but only on the day, so settled results stay put
  def deletable_by?(user)
    challenge_participant.user_id == user&.id && checked_in_on == Time.zone.today
  end

  # Friends hear about your day once; later check-ins just show up in the feed
  def notify_other_participants
    return unless first_of_the_day?

    challenge_story.active_participants.where.not(id: challenge_participant_id).includes(:user).find_each do |participant|
      participant.user.notify(
        title: "#{challenge_participant.name} checked in",
        body: "#{challenge_story.title}: #{message.truncate(80)}",
        path: Rails.application.routes.url_helpers.challenge_story_path(challenge_story)
      )
    end
  end

  def liked_by?(user)
    return false unless user

    challenge_check_in_likes.exists?(user: user)
  end

  private

  def broadcast_to_story_and_participant_feeds
    broadcast_prepend_to challenge_story,
      target: "challenge_check_ins",
      partial: "challenge_check_ins/challenge_check_in",
      locals: {challenge_check_in: self, show_challenge: false}

    User.where(id: challenge_story.challenge_participants.select(:user_id)).find_each do |user|
      broadcast_prepend_to [user, "challenge_check_ins_feed"],
        target: "challenge_check_ins_feed",
        partial: "challenge_check_ins/challenge_check_in",
        locals: {challenge_check_in: self, show_challenge: true}
    end
  end

  def remove_from_story_and_participant_feeds
    broadcast_remove_to challenge_story

    User.where(id: challenge_story.challenge_participants.select(:user_id)).find_each do |user|
      broadcast_remove_to [user, "challenge_check_ins_feed"]
    end
  end

  def photo_size_validation
    return unless photo.present? && photo.blob.byte_size > 10.megabytes

    errors.add(:photo, "is too large (maximum 10MB)")
  end
end
