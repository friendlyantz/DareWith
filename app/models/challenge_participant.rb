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
    @streak ||= Streak.new(check_in_dates, challenge_story.goal)
  end

  # Days with a check-in, or weeks that hit the weekly count
  def periods_kept
    challenge_story.goal.kept_period_indexes(check_in_dates).count { it >= 0 }
  end

  def check_ins_this_period
    challenge_story.goal.check_ins_in_period(check_in_dates)
  end

  def period_kept?
    check_ins_this_period >= challenge_story.times_per_period
  end

  # Nothing left to do today: checked in, or this week's check-ins are done
  def done_for_now?
    checked_in_today? || period_kept?
  end

  # Daily: any day without a check-in. Weekly: only once the days left are just enough
  def reminder_due_today?
    return false if done_for_now?
    return true if challenge_story.daily?

    challenge_story.times_per_period - check_ins_this_period >= challenge_story.goal.days_left_in_period
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
