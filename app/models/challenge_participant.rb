# frozen_string_literal: true

class ChallengeParticipant < ApplicationRecord
  # Associations
  belongs_to :user, counter_cache: true
  belongs_to :challenge_story, counter_cache: true
  has_many :given_rewards, class_name: "ChallengeReward", foreign_key: "giver_id", dependent: :destroy
  has_many :received_rewards, class_name: "ChallengeReward", foreign_key: "receiver_id", dependent: :destroy
  has_many :challenge_check_ins, dependent: :destroy
  has_many :todays_check_ins, -> { today.counted }, class_name: "ChallengeCheckIn"
  # Just enough of each counted check-in for streaks and totals, so pages can preload it cheaply
  has_many :check_in_days, -> { counted.select(:id, :challenge_participant_id, :checked_in_on, :amount) }, class_name: "ChallengeCheckIn"
  has_many :sent_nudges, class_name: "ChallengeNudge", foreign_key: "sender_id", dependent: :destroy
  has_many :received_nudges, class_name: "ChallengeNudge", foreign_key: "receiver_id", dependent: :destroy
  # Wide enough to hold "today" in any time zone, so pages can preload it
  has_many :recent_nudges, -> { where(nudged_on: (Date.current - 1)..).order(:created_at) }, class_name: "ChallengeNudge", foreign_key: "receiver_id"

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
    @streak ||= Streak.new(check_in_days, challenge_story.goal)
  end

  def pending_rewards_count
    given_rewards.pending.count + received_rewards.pending.count
  end

  # Days or weeks that hit the goal
  def periods_kept
    challenge_story.goal.kept_period_indexes(check_in_days).count { it >= 0 }
  end

  # Days or weeks short of the goal that are over and that no freeze covered.
  # Only ones since joining count; a week you joined partway through doesn't.
  def misses
    goal = challenge_story.goal
    missed = goal.closed_period_indexes - goal.kept_period_indexes(check_in_days) - streak.frozen_indexes
    missed.count { it >= goal.first_full_period_from(joined_on) }
  end

  def joined_on
    created_at.to_date
  end

  def total_amount
    check_in_days.sum { it.amount || 0 }
  end

  def forecast
    Forecast.new(self)
  end

  def latest_photo_check_in
    challenge_check_ins.joins(:photo_attachment).order(created_at: :desc).first
  end

  def check_ins_this_period
    challenge_story.goal.check_ins_in_period(check_in_days)
  end

  def amount_this_period
    challenge_story.goal.amount_in_period(check_in_days)
  end

  def period_kept?
    challenge_story.goal.period_kept?(check_in_days)
  end

  # Nothing left to do today: today or this week hit the goal, or in a weekly challenge, checked in today
  def done_for_now?
    period_kept? || (challenge_story.weekly? && checked_in_today?)
  end

  # Daily: any day short of the goal. Weekly: once the days left are just enough,
  # or on the last day when the days are done but the target isn't
  def reminder_due_today?
    return false if done_for_now?
    return true if challenge_story.daily?

    days_left = challenge_story.goal.days_left_in_period
    days_left == 1 || challenge_story.times_per_period - check_ins_this_period >= days_left
  end

  def local_today
    Time.current.in_time_zone(user.time_zone).to_date
  end

  def nudges_today
    recent_nudges.select { it.nudged_on == local_today }
  end

  def nudged_today?
    nudges_today.any?
  end

  def nudged_today_by?(participant)
    nudges_today.any? { it.sender_id == participant.id }
  end

  # A friend who's done today can nudge someone in the same running challenge who isn't
  def nudgeable_by?(participant)
    participant.present? && participant != self &&
      participant.active? && active? &&
      participant.challenge_story_id == challenge_story_id &&
      challenge_story.accepting_check_ins? && challenge_story.start <= Time.zone.today &&
      participant.checked_in_today? && !done_for_now?
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
    transaction do
      update!(status: :inactive)
      challenge_story.settle_open_disputes!
    end
  end

  def rejoin!
    transaction do
      update!(status: :active)
      challenge_story.settle_open_disputes!
    end
  end

  def has_pledged_to_all_active_participants?
    other_active_ids = challenge_story.active_participants.where.not(id: id).pluck(:id)
    return true if other_active_ids.empty?

    pledged_ids = given_rewards.pledge.pluck(:receiver_id)
    (other_active_ids - pledged_ids).empty?
  end

  def friends
    challenge_story.active_participants.where.not(id: id)
  end

  def unpledged_participants
    pledged_ids = given_rewards.pledge.pluck(:receiver_id)
    challenge_story.active_participants
      .where.not(id: id)
      .where.not(id: pledged_ids)
  end

  def missing_pledges?
    !has_pledged_to_all_active_participants?
  end

  private

  def set_default_name
    self.name = user.username if user.present?
  end
end
