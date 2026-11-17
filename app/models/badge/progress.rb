# frozen_string_literal: true

# How close a user is to the badges they haven't earned yet
class Badge::Progress
  Step = Data.define(:kind, :current, :goal, :unit) do
    def badge = Badge.new(kind:)
  end

  private attr_reader :user, :earned_kinds

  def initialize(user, earned_kinds: user.badges.distinct.pluck(:kind))
    @user = user
    @earned_kinds = earned_kinds
  end

  def next_up(limit: 2)
    [first_check_in, streak, cheerleader].compact
      .sort_by { -it.current.fdiv(it.goal) }
      .first(limit)
  end

  private

  def first_check_in
    Step.new(kind: "first_check_in", current: 0, goal: 1, unit: "check-in") unless earned?(:first_check_in)
  end

  def streak
    kind, days = Badge::Awarder::STREAK_DAYS.find { |kind, _days| !earned?(kind) }
    return unless kind

    Step.new(kind: kind.to_s, current: [best_current_streak, days].min, goal: days, unit: "days in a row")
  end

  def cheerleader
    return if earned?(:cheerleader)

    goal = Badge::Awarder::CHEERLEADER_LIKES
    Step.new(kind: "cheerleader", current: [user.liked_friends_check_ins_count, goal].min, goal:, unit: "likes")
  end

  def best_current_streak
    user.challenge_participants.active
      .merge(ChallengeStory.active.daily).joins(:challenge_story)
      .includes(:check_in_days)
      .map { it.streak.current }.max || 0
  end

  def earned?(kind)
    earned_kinds.include?(kind.to_s)
  end
end
