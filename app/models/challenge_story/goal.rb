# frozen_string_literal: true

# What a challenge asks for: how often to check in (cadence) and, optionally,
# what to count (unit) and how much (target)
class ChallengeStory::Goal
  DECIMAL_UNITS = %w[hours km].freeze

  private attr_reader :challenge_story

  delegate :cadence, :times_per_period, :unit, :target_amount, :target_scope,
    :weekly?, :each_time?, :total?, :start, :finish, :duration_in_days, to: :challenge_story

  def initialize(challenge_story)
    @challenge_story = challenge_story
  end

  # Periods are days, or weeks counted from the start date
  def period_name
    weekly? ? "week" : "day"
  end

  def period_length
    weekly? ? 7 : 1
  end

  def period_count
    duration_in_days.fdiv(period_length).ceil
  end

  # Zero-based, and not clamped, so the day after the end is past the last period
  def period_index(date)
    (date - start).to_i.div(period_length)
  end

  def current_period_number(today = Time.zone.today)
    period_index(today).clamp(0, period_count - 1) + 1
  end

  # "Day 3 of 30", "Week 2 of 4"
  def progress_label(today = Time.zone.today)
    "#{period_name.capitalize} #{current_period_number(today)} of #{period_count}"
  end

  def days_left_in_period(today = Time.zone.today)
    period_length - (today - start).to_i.modulo(period_length)
  end

  # Check-ins on the grace day after the end count toward the last period.
  # Ones before the start keep their negative index, so they can still begin a streak.
  def kept_period_indexes(dates)
    dates.uniq
      .map { [period_index(it), period_count - 1].min }
      .tally.select { |_index, check_ins| check_ins >= times_per_period }
      .keys.sort
  end

  # Periods that are over. The last one stays open through the grace day after the end.
  def closed_period_indexes(today = Time.zone.today)
    closed = (challenge_story.completed? || today > finish + 1) ? period_count : [period_index(today), period_count - 1].min
    (0...closed).to_a
  end

  def check_ins_in_period(dates, today = Time.zone.today)
    dates.uniq.count { period_index(it) == period_index(today) }
  end

  def measured?
    unit.present?
  end

  def targeted?
    target_amount.present?
  end

  # Nobody does half a push-up, but 5.2 km is a normal run and 1.5 hours a normal session
  def whole_numbers?
    measured? && DECIMAL_UNITS.exclude?(unit)
  end

  # Pre-fills the check-in so hitting the target is one tap
  def suggested_amount
    target_amount if each_time?
  end

  # "3× a week · 5 km each time", or nil for a plain daily challenge
  def summary
    [frequency, target].compact.join(" · ").presence
  end

  # 50 → "50 reps", 1 → "1 rep", 5.25 → "5.25 km"
  def format_amount(amount)
    "#{format_number(amount)} #{unit_label(amount)}"
  end

  # 50.0 → "50", 5.25 → "5.25"
  def format_number(amount)
    ActiveSupport::NumberHelper.number_to_rounded(amount, precision: 2, strip_insignificant_zeros: true)
  end

  def unit_label(amount = nil)
    (amount == 1 && unit != "km") ? unit.singularize : unit
  end

  private

  def frequency
    "#{times_per_period}× a week" if weekly?
  end

  def target
    return unless measured?
    return "counting #{unit_label}" unless targeted?

    "#{format_amount(target_amount)} #{each_time? ? "each time" : "each by the end"}"
  end
end
