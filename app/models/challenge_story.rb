# frozen_string_literal: true

class ChallengeStory < ApplicationRecord
  MAX_PARTICIPANTS = 4
  AUTO_COMPLETE_AFTER = 14.days

  # Associations
  belongs_to :previous_challenge_story, class_name: "ChallengeStory", optional: true
  has_one :next_challenge_story, class_name: "ChallengeStory", foreign_key: :previous_challenge_story_id, dependent: :nullify, inverse_of: :previous_challenge_story
  has_many :challenge_check_ins, -> { order(created_at: :desc) }, dependent: :destroy, inverse_of: :challenge_story
  has_many :challenge_participants, dependent: :destroy
  has_many :challenge_rewards, dependent: :destroy
  has_many :challenge_story_likes, dependent: :destroy
  has_many :active_participants, -> { active }, class_name: "ChallengeParticipant"
  has_many :liking_users, through: :challenge_story_likes, source: :user
  has_many :badges, dependent: :destroy

  # Broadcasts (after associations)
  broadcasts_refreshes

  # Enums
  enum :cadence, %w[daily weekly].index_by(&:itself), validate: true
  enum :unit, %w[reps minutes hours km pages].index_by(&:itself), prefix: :counts, validate: {allow_nil: true}
  enum :target_scope, %w[each_time total].index_by(&:itself), validate: {allow_nil: true}

  # Validations
  validates :title, presence: true
  validates :description, presence: true, length: {maximum: 500}
  validates :start, :finish, presence: true
  validate :finish_cannot_be_earlier_than_start
  validate :whole_weeks, if: :weekly?
  validates :times_per_period, inclusion: {in: ->(story) { story.weekly? ? 1..6 : [1] }}
  validates :target_amount, numericality: {greater_than: 0, less_than: 100_000_000}, allow_nil: true
  validate :whole_number_target, if: -> { goal.whole_numbers? }
  validates :target_scope, presence: true, if: -> { target_amount.present? }
  validate :goal_locked_after_first_check_in, on: :update

  # Callbacks
  # The form always sends a weekly count and a scope, and a target only means something with a unit
  before_validation do
    self.times_per_period = 1 if daily?
    self.target_amount = nil if unit.blank?
    self.target_scope = nil if target_amount.blank?
  end

  before_create do
    self.round = previous_challenge_story.round + 1 if previous_challenge_story
  end

  # Scopes
  scope :active, -> { where(completed: false) }
  scope :completed, -> { where(completed: true) }

  # Public methods
  def goal
    @goal ||= Goal.new(self)
  end

  def finale
    Finale.new(self)
  end

  def goal_editable?
    new_record? || challenge_check_ins_count.zero?
  end

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
    if total?
      active_participants.sort_by { [-it.total_amount, -it.periods_kept] }
    else
      active_participants.sort_by { [-it.periods_kept, -it.total_amount] }
    end
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
        body: "See how it went: photos, streaks and who stood out.",
        path: Rails.application.routes.url_helpers.challenge_story_challenge_finale_path(self)
      )
    end
  end

  # Same rules and length, starting today
  def next_round
    ChallengeStory.new(
      previous_challenge_story: self,
      title:,
      description:,
      cadence:,
      times_per_period:,
      unit:,
      target_amount:,
      target_scope:,
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

  def whole_weeks
    return if start.blank? || finish.blank? || finish < start || (duration_in_days % 7).zero?

    errors.add(:finish, "must make whole weeks for a weekly challenge, e.g. #{(start + (duration_in_days.fdiv(7).ceil * 7 - 1).days).strftime("%-d %b")}")
  end

  # A saved 50 loads as BigDecimal("50"), which numericality's only_integer rejects
  def whole_number_target
    return if target_amount.nil? || target_amount == target_amount.round

    errors.add(:target_amount, "must be a whole number")
  end

  # Check-ins already count toward the old goal, so changing it would rewrite history
  def goal_locked_after_first_check_in
    return if challenge_check_ins_count.zero?
    return unless (changed & %w[cadence times_per_period unit target_amount target_scope]).any?

    errors.add(:base, "The goal can't change once someone has checked in")
  end
end
