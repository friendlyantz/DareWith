# frozen_string_literal: true

# What a challenge asks for: how often to check in (cadence) and, optionally,
# what to count (unit) and how much (target)
class ChallengeStory::Goal
  private attr_reader :challenge_story

  delegate :cadence, :times_per_period, :unit, :target_amount, :target_scope,
    :weekly?, :each_time?, :total?, to: :challenge_story

  def initialize(challenge_story)
    @challenge_story = challenge_story
  end

  def measured?
    unit.present?
  end

  def targeted?
    target_amount.present?
  end

  # Nobody does half a push-up, but 5.2 km is a normal run
  def whole_numbers?
    measured? && unit != "km"
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

    "#{format_amount(target_amount)} #{each_time? ? "each time" : "in total"}"
  end
end
