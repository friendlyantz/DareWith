# frozen_string_literal: true

class ChallengeStory < ApplicationRecord
  MAX_PARTICIPANTS = 4
  AUTO_COMPLETE_AFTER = 14.days

  # Associations
  belongs_to :previous_challenge_story, class_name: "ChallengeStory", optional: true
  has_one :next_challenge_story, class_name: "ChallengeStory", foreign_key: :previous_challenge_story_id, dependent: :nullify, inverse_of: :previous_challenge_story
  has_many :challenge_check_ins, -> { order(created_at: :desc) }, dependent: :destroy
  has_many :challenge_participants, dependent: :destroy
  has_many :challenge_rewards, dependent: :destroy
  has_many :challenge_story_likes, dependent: :destroy
  has_many :active_participants, -> { active }, class_name: "ChallengeParticipant"
  has_many :liking_users, through: :challenge_story_likes, source: :user
  has_many :badges, dependent: :destroy

  # Broadcasts (after associations)
  broadcasts_refreshes

  # Validations
  validates :title, presence: true
  validates :description, presence: true, length: {maximum: 500}
  validates :start, :finish, presence: true
  validate :finish_cannot_be_earlier_than_start

  # Callbacks
  before_create do
    self.round = previous_challenge_story.round + 1 if previous_challenge_story
  end

  # Scopes
  scope :active, -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }

  # Public methods
  def finished?
    finish < Time.zone.today
  end

  # Settling pledges opens on the last day, when people actually settle up
  def settle_up_open?
    Time.zone.today >= finish
  end

  def duration_in_days
    (finish - start).to_i + 1
  end

  def current_day
    ((Time.zone.today - start).to_i + 1).clamp(1, duration_in_days)
  end

  def accepting_check_ins?
    !completed? && Time.zone.today <= finish + 1.day
  end

  def wrapping_up?
    !completed? && !accepting_check_ins?
  end

  def auto_complete_on
    finish + AUTO_COMPLETE_AFTER
  end

  def ready_to_auto_complete?
    wrapping_up? && (challenge_rewards.pending.none? || Time.zone.today >= auto_complete_on)
  end

  def checked_in_today_count
    active_participants.count(&:checked_in_today?)
  end

  def ranked_participants
    active_participants.sort_by { -it.challenge_check_ins_count }
  end

  def participant_for(user)
    active_participants.find { it.user_id == user.id }
  end

  def latest_photo_check_in
    challenge_check_ins.joins(:photo_attachment).first
  end

  def liked_by?(user)
    return false unless user
    challenge_story_likes.exists?(user: user)
  end

  def at_capacity?
    active_participants.size >= MAX_PARTICIPANTS
  end

  def available_spots
    MAX_PARTICIPANTS - active_participants.size
  end

  def mark_complete!(by: nil)
    update!(completed: true)
    announce_completion(except: by)
    award_badges
  end

  def award_badges
    active_participants.includes(:user).find_each { BadgeAwardJob.perform_later(it.user) }
  end

  def announce_completion(except: nil)
    active_participants.where.not(user: except).includes(:user).find_each do |participant|
      participant.user.notify(
        title: "#{title} is complete",
        body: "It's moved to your past challenges.",
        path: Rails.application.routes.url_helpers.challenge_story_path(self)
      )
    end
  end

  # Same rules and length, starting today
  def next_round
    ChallengeStory.new(
      previous_challenge_story: self,
      title:,
      description:,
      start: Time.zone.today,
      finish: Time.zone.today + (duration_in_days - 1).days
    )
  end

  def invite_to_next_round(by:)
    previous_challenge_story.active_participants.where.not(user: by).includes(:user).find_each do |participant|
      participant.user.notify(
        title: "#{by.username} started round #{round} of #{title}",
        body: "Same rules, new dates. Tap to join.",
        path: Rails.application.routes.url_helpers.challenge_story_path(self)
      )
    end
  end

  def find_or_activate_participant!(user)
    participant = challenge_participants.find_by(user: user)

    if participant
      participant.update!(status: :active) if participant.inactive?
      participant
    else
      challenge_participants.create!(user: user, status: :active)
    end
  end

  private

  def finish_cannot_be_earlier_than_start
    if finish.present? && start.present? && finish < start
      errors.add(:finish, "cannot be earlier than the start date")
    end
  end
end
