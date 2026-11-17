# frozen_string_literal: true

# A friend's "your turn" push. Only the first nudge a person gets in a challenge each day pushes;
# the rest just show in the app
class ChallengeNudge < ApplicationRecord
  # Associations
  belongs_to :sender, class_name: "ChallengeParticipant"
  belongs_to :receiver, class_name: "ChallengeParticipant"

  # Validations
  validates :sender_id, uniqueness: {scope: [:receiver_id, :nudged_on], message: "already nudged them today"}
  validate :receiver_nudgeable_by_sender

  # Callbacks
  before_validation -> { self.nudged_on ||= receiver&.local_today }

  # Public methods
  def deliver
    return unless first_today?

    challenge_story = receiver.challenge_story
    receiver.user.notify(
      title: "#{sender.name} nudged you 👋",
      body: "Your turn on #{challenge_story.title}. #{sender.name} already checked in today.",
      path: Rails.application.routes.url_helpers.challenge_story_path(challenge_story)
    )
  end

  private

  def first_today?
    ChallengeNudge.where(receiver_id:, nudged_on:).where.not(id:).none?
  end

  def receiver_nudgeable_by_sender
    errors.add(:receiver, "can't be nudged right now") unless receiver&.nudgeable_by?(sender)
  end
end
