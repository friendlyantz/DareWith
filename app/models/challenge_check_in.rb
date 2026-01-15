# frozen_string_literal: true

class ChallengeCheckIn < ApplicationRecord
  # Associations
  belongs_to :challenge_participant, counter_cache: true
  belongs_to :challenge_story, counter_cache: true
  has_one_attached :photo
  has_many :challenge_check_in_likes, dependent: :destroy
  has_many :liking_users, through: :challenge_check_in_likes, source: :user

  # Validations
  validates :message, presence: true
  validate :photo_size_validation
  validate :one_check_in_per_day_per_participant

  # Callbacks (broadcasts must be after has_one_attached for Cloudinary compatibility)
  after_create_commit :broadcast_to_story_and_participant_feeds

  # Public methods
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

  def photo_size_validation
    return unless photo.present? && photo.blob.byte_size > 10.megabytes

    errors.add(:photo, "is too large (maximum 10MB)")
  end

  def one_check_in_per_day_per_participant
    return if challenge_participant.blank?

    existing_check_in_today = ChallengeCheckIn.unscoped.exists?(
      challenge_participant_id: challenge_participant_id,
      created_at: Time.zone.today.all_day
    )

    return unless existing_check_in_today && new_record?

    errors.add(:base, "You can only check in once per day")
  end
end
