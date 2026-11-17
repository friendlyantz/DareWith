# frozen_string_literal: true

# A friend questioning a check-in. Doubts show who doubted, and enough of them dispute it.
class ChallengeCheckInDoubt < ApplicationRecord
  include ActionView::RecordIdentifier

  NOTE_MAX_LENGTH = 140

  # Associations
  belongs_to :challenge_check_in
  belongs_to :user

  # Normalization
  normalizes :note, with: -> { it.strip.presence }

  # Validations
  validates :user_id, uniqueness: {scope: :challenge_check_in_id}
  validates :note, length: {maximum: NOTE_MAX_LENGTH}

  # Broadcasts
  # Friends watching see the doubt, and the leaderboard if it changes who counts
  after_commit :broadcast_refresh_to_story_and_participant_feeds

  # Public methods
  def notify_author
    challenge_check_in.challenge_participant.user.notify(
      title: "#{user.username} doubts your check-in",
      body: challenge_check_in.disputed? ? "It's disputed and won't count unless doubts are withdrawn. Reply with proof." : note || "Reply with proof to win them over.",
      path: Rails.application.routes.url_helpers.challenge_story_path(challenge_check_in.challenge_story, anchor: dom_id(challenge_check_in))
    )
  end

  private

  def broadcast_refresh_to_story_and_participant_feeds
    challenge_story = challenge_check_in.challenge_story
    challenge_story.broadcast_refresh_later

    User.where(id: challenge_story.challenge_participants.select(:user_id)).find_each do |participant_user|
      broadcast_refresh_later_to participant_user, "challenge_check_ins_feed"
    end
  end
end
