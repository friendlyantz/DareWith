# frozen_string_literal: true

class ChallengeParticipant < ApplicationRecord
  # Associations
  belongs_to :user, counter_cache: true
  belongs_to :challenge_story, counter_cache: true
  has_many :given_rewards, class_name: "ChallengeReward", foreign_key: "giver_id", dependent: :destroy
  has_many :received_rewards, class_name: "ChallengeReward", foreign_key: "receiver_id", dependent: :destroy
  has_many :challenge_check_ins, dependent: :destroy
  has_many :todays_check_ins, -> { today }, class_name: "ChallengeCheckIn"
  has_many :check_in_days, -> { select(:id, :challenge_participant_id, :checked_in_on) }, class_name: "ChallengeCheckIn"

  # Enums
  enum :status, %w[active inactive].index_by(&:itself)

  # Scopes
  scope :active, -> { where(status: :active) }
  scope :inactive, -> { where(status: :inactive) }

  # Callbacks
  before_create :set_default_name

  # Public methods
  def checked_in_today?
    todays_check_ins.any?
  end

  def streak
    @streak ||= Streak.new(check_in_dates)
  end

  # Days with a check-in while the challenge ran, counting the grace day after it
  def days_checked_in
    (check_in_dates & (challenge_story.start..challenge_story.finish + 1.day).to_a).size
      .clamp(0, challenge_story.duration_in_days)
  end

  def announce_joining
    challenge_story.active_participants.where.not(id:).includes(:user).find_each do |participant|
      participant.user.notify(
        title: "#{name} joined #{challenge_story.title}",
        path: Rails.application.routes.url_helpers.challenge_story_path(challenge_story)
      )
    end
  end

  def leave!
    update!(status: :inactive)
  end

  def rejoin!
    update!(status: :active)
  end

  def has_pledged_to_all_active_participants?
    other_active_ids = challenge_story.active_participants.where.not(id: id).pluck(:id)
    return true if other_active_ids.empty?

    pledged_ids = given_rewards.pluck(:receiver_id)
    (other_active_ids - pledged_ids).empty?
  end

  def unpledged_participants
    pledged_ids = given_rewards.pluck(:receiver_id)
    challenge_story.active_participants
      .where.not(id: id)
      .where.not(id: pledged_ids)
  end

  def missing_pledges?
    !has_pledged_to_all_active_participants?
  end

  private

  def check_in_dates
    @check_in_dates ||= check_in_days.map(&:checked_in_on).uniq
  end

  def set_default_name
    self.name = user.username if user.present?
  end
end
