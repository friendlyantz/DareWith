# frozen_string_literal: true

class ChallengeCheckInReply < ApplicationRecord
  include ActionView::RecordIdentifier

  MAX_LENGTH = 280

  # Associations
  belongs_to :challenge_check_in, counter_cache: true
  belongs_to :user, counter_cache: true

  # Normalization
  normalizes :body, with: ->(body) { body.strip }

  # Validations
  validates :body, presence: true, length: {maximum: MAX_LENGTH}

  # Broadcasts
  after_create_commit :broadcast_to_story_and_participant_feeds

  # Public methods
  # The check-in's author and everyone else who replied, except whoever just wrote
  def notify_thread
    author = challenge_check_in.challenge_participant.user
    recipient_ids = [author.id, *ChallengeCheckInReply.where(challenge_check_in_id:).distinct.pluck(:user_id)].uniq - [user_id]

    User.where(id: recipient_ids).find_each do |recipient|
      recipient.notify(
        title: (recipient == author) ? "#{user.username} replied to your check-in" : "#{user.username} replied on #{author.username}'s check-in",
        body: body.truncate(80),
        path: Rails.application.routes.url_helpers.challenge_story_path(challenge_check_in.challenge_story, anchor: dom_id(challenge_check_in))
      )
    end
  end

  private

  def broadcast_to_story_and_participant_feeds
    target = dom_id(challenge_check_in, :replies)
    broadcast_append_to(challenge_check_in.challenge_story, target:)

    User.where(id: challenge_check_in.challenge_story.challenge_participants.select(:user_id)).find_each do |participant_user|
      broadcast_append_to([participant_user, "challenge_check_ins_feed"], target:)
    end
  end
end
