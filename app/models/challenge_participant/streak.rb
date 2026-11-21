# frozen_string_literal: true

# Runs of consecutive kept periods (days or weeks that hit the goal) within one challenge.
# In daily challenges every 7 days in a row earn a freeze, and a freeze covers one missed day,
# so a long streak survives a slip. A covered day keeps the streak alive but doesn't add to it.
class ChallengeParticipant::Streak
  COMEBACK_AFTER_MISSED_PERIODS = 2
  FREEZE_EVERY = 7
  MAX_FREEZES = 2

  Run = Struct.new(:first, :last, :kept, :freezes, :earned_at)

  private attr_reader :goal, :kept_indexes

  def initialize(check_ins, goal)
    @goal = goal
    @kept_indexes = goal.kept_period_indexes(check_ins)
  end

  # Still counts until the current period ends, so a streak isn't broken before you've had the chance to keep it
  def current(today = Time.zone.today)
    alive?(today) ? runs.last.kept : 0
  end

  def longest
    runs.map(&:kept).max || 0
  end

  # Freezes left to cover the next missed days
  def freezes(today = Time.zone.today)
    alive?(today) ? runs.last.freezes - missed_since_last(today) : 0
  end

  def frozen_yesterday?(today = Time.zone.today)
    yesterday = goal.period_index(today) - 1
    alive?(today) && runs.last.first < yesterday && kept_indexes.exclude?(yesterday)
  end

  def freeze_earned_today?(today = Time.zone.today)
    alive?(today) && runs.last.earned_at == goal.period_index(today)
  end

  # Days in a row still to go for the next freeze, or nil when none can be earned
  def days_to_next_freeze(today = Time.zone.today)
    return if goal.weekly? || freezes(today) >= MAX_FREEZES

    FREEZE_EVERY - current(today) % FREEZE_EVERY
  end

  # Missed periods a freeze covered. A gap longer than the freezes left still breaks the streak,
  # but its first days use them up, so those aren't misses either.
  def frozen_indexes(today = Time.zone.today)
    runs.each_with_index.flat_map do |run, i|
      gap_end = runs[i + 1]&.first || goal.period_index(today)
      ((run.first..run.last).to_a - kept_indexes) + ((run.last + 1)...gap_end).first(run.freezes)
    end
  end

  # Counts real misses, even ones a freeze covered
  def comeback?
    kept_indexes.each_cons(2).any? { |index, next_index| next_index - index - 1 >= COMEBACK_AFTER_MISSED_PERIODS }
  end

  private

  def alive?(today)
    runs.any? && missed_since_last(today) <= runs.last.freezes
  end

  # Missed periods before the current one, which is still open
  def missed_since_last(today)
    [goal.period_index(today) - 1 - runs.last.last, 0].max
  end

  # Kept periods joined across the gaps that freezes covered
  def runs
    @runs ||= kept_indexes.each_with_object([]) do |index, runs|
      run = runs.last
      missed = run && index - run.last - 1
      if run && missed <= run.freezes
        run.freezes -= missed
      else
        runs << (run = Run.new(first: index, kept: 0, freezes: 0))
      end
      run.last = index
      run.kept += 1
      earn_freeze(run, index)
    end
  end

  def earn_freeze(run, index)
    return if goal.weekly? || (run.kept % FREEZE_EVERY).nonzero? || run.freezes >= MAX_FREEZES

    run.freezes += 1
    run.earned_at = index
  end
end
