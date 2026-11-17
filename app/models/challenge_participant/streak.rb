# frozen_string_literal: true

# Runs of consecutive kept periods (days, or weeks that hit the weekly count) within one challenge
class ChallengeParticipant::Streak
  COMEBACK_AFTER_MISSED_PERIODS = 2

  private attr_reader :goal, :runs

  def initialize(dates, goal)
    @goal = goal
    @runs = goal.kept_period_indexes(dates).slice_when { |index, next_index| next_index != index + 1 }.to_a
  end

  # Still counts until the current period ends, so a streak isn't broken before you've had the chance to keep it
  def current(today = Time.zone.today)
    last_run = runs.last
    return 0 unless last_run && last_run.last >= goal.period_index(today) - 1

    last_run.size
  end

  def longest
    runs.map(&:size).max || 0
  end

  def comeback?
    runs.each_cons(2).any? { |run, next_run| next_run.first - run.last - 1 >= COMEBACK_AFTER_MISSED_PERIODS }
  end
end
