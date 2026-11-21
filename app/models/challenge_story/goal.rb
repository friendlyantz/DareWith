# frozen_string_literal: true

# What a challenge asks for: how often to check in (cadence) and, optionally,
# what to count (unit) and how much (target)
class ChallengeStory::Goal
  DECIMAL_UNITS = %w[hours km].freeze

  private attr_reader :challenge_story

  delegate :cadence, :times_per_period, :unit, :target_amount, :target_scope,
    :weekly?, :each_period?, :total?, :start, :finish, :duration_in_days, to: :challenge_story

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

  # The first period that starts on or after the date
  def first_full_period_from(date)
    [(date - start).to_i.fdiv(period_length).ceil, 0].max
  end

  def current_period_number(today = Time.zone.today)
    period_index(today).clamp(0, period_count - 1) + 1
  end

  # "Day 3 of 30", "Week 2 of 4"
  def progress_label(today = Time.zone.today)
    "#{period_name.capitalize} #{current_period_number(today)} of #{period_count}"
  end

  # The grace day after the end is the last day of the last period
  def days_left_in_period(today = Time.zone.today)
    return 1 if today > finish

    period_length - (today - start).to_i.modulo(period_length)
  end

  # Ones before the start keep their negative index, so they can still begin a streak
  def kept_period_indexes(check_ins)
    check_ins.group_by { counted_period_index(it.checked_in_on) }
      .select { |_index, period_check_ins| kept?(period_check_ins) }
      .keys.sort
  end

  # Periods that are over. The last one stays open through the grace day after the end.
  def closed_period_indexes(today = Time.zone.today)
    closed = (challenge_story.completed? || today > finish + 1) ? period_count : [period_index(today), period_count - 1].min
    (0...closed).to_a
  end

  def period_kept?(check_ins, today = Time.zone.today)
    kept?(in_period(check_ins, today))
  end

  # Days checked in, however many check-ins each had
  def check_ins_in_period(check_ins, today = Time.zone.today)
    in_period(check_ins, today).map(&:checked_in_on).uniq.size
  end

  def amount_in_period(check_ins, today = Time.zone.today)
    in_period(check_ins, today).sum { it.amount || 0 }
  end

  # "Weeks with 3 check-ins and 15 km", "Days with 50 reps", "Days checked in"
  def kept_rule
    requirements = []
    requirements << "#{times_per_period} check-ins" if weekly?
    requirements << format_amount(target_amount) if each_period?
    return "Days checked in" if requirements.empty?

    "#{period_name.pluralize.capitalize} with #{requirements.to_sentence}"
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

  # Pre-fills the check-in so hitting the target is one tap, or for a weekly target, an even share of it
  def suggested_amount
    return unless each_period?

    share = target_amount / times_per_period
    whole_numbers? ? share.ceil : share.round(2)
  end

  # "3× a week · 15 km a week", or nil for a plain daily challenge
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

  # Check-ins on the grace day after the end count toward the last period
  def counted_period_index(date)
    [period_index(date), period_count - 1].min
  end

  # So on the grace day, "this week" is still the last week
  def in_period(check_ins, today)
    check_ins.select { counted_period_index(it.checked_in_on) == counted_period_index(today) }
  end

  # Enough days checked in and, with a target each period, enough counted between them,
  # so two short runs on one day count the same as one long one
  def kept?(check_ins)
    check_ins.map(&:checked_in_on).uniq.size >= times_per_period &&
      (!each_period? || check_ins.sum { it.amount || 0 } >= target_amount)
  end

  def frequency
    "#{times_per_period}× a week" if weekly?
  end

  def target
    return unless measured?
    return "counting #{unit_label}" unless targeted?

    "#{format_amount(target_amount)} #{each_period? ? "a #{period_name}" : "each by the end"}"
  end
end
