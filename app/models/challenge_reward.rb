# frozen_string_literal: true

class ChallengeReward < ApplicationRecord
  # Associations
  belongs_to :giver, class_name: "ChallengeParticipant", counter_cache: :given_rewards_count
  belongs_to :receiver, class_name: "ChallengeParticipant", counter_cache: :received_rewards_count
  belongs_to :challenge_story, counter_cache: true

  # Enums
  enum :status, %w[pending fulfilled canceled].index_by(&:itself)
  # A pledge is promised during the challenge; a penalty is owed for misses once it closes
  enum :kind, %w[pledge penalty].index_by(&:itself)

  # Validations
  validates :description, presence: true
  validates :giver_id, uniqueness: {scope: [:receiver_id, :challenge_story_id, :kind], message: "has already pledged a reward to this participant"}
  validate :cannot_reward_self
  validate :participants_in_same_challenge

  # Scopes
  scope :pending, -> { where(status: :pending) }
  scope :fulfilled, -> { where(status: :fulfilled) }
  scope :canceled, -> { where(status: :canceled) }

  # Public methods
  def fulfill!
    update!(status: :fulfilled, fulfilled_at: Time.current)
  end

  def cancel!
    update!(status: :canceled)
  end

  def notify_receiver
    receiver.user.notify(
      title: penalty? ? "#{giver.name} owes you for missing" : "#{giver.name} pledged you a reward",
      body: description.truncate(80),
      path: rewards_path
    )
  end

  def notify_giver_of_fulfilment
    giver.user.notify(
      title: "#{receiver.name} received your reward",
      body: description.truncate(80),
      path: rewards_path
    )
  end

  private

  def rewards_path
    Rails.application.routes.url_helpers.challenge_story_challenge_rewards_path(challenge_story)
  end

  def cannot_reward_self
    errors.add(:receiver_id, "can't be the same as giver") if giver_id == receiver_id
  end

  def participants_in_same_challenge
    return unless giver && receiver
    return if giver.challenge_story_id == receiver.challenge_story_id

    errors.add(:base, "Both participants must be in the same challenge")
  end
end
