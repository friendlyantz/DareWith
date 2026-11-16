# frozen_string_literal: true

# Runs of consecutive check-in days within one challenge
class ChallengeParticipant::Streak
  COMEBACK_AFTER_MISSED_DAYS = 2

  private attr_reader :runs

  def initialize(dates)
    @runs = dates.uniq.sort.slice_when { |day, next_day| next_day != day + 1 }.to_a
  end

  # Still counts until the end of today, so a streak isn't broken before you've had the chance to check in
  def current(today = Time.zone.today)
    last_run = runs.last
    return 0 unless last_run && last_run.last >= today - 1

    last_run.size
  end

  def longest
    runs.map(&:size).max || 0
  end

  def comeback?
    runs.each_cons(2).any? { |run, next_run| next_run.first - run.last - 1 >= COMEBACK_AFTER_MISSED_DAYS }
  end
end
