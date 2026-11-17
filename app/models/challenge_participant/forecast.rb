# frozen_string_literal: true

# Where someone's daily average so far takes them, for "by the end" targets
class ChallengeParticipant::Forecast
  private attr_reader :participant, :today

  delegate :challenge_story, :total_amount, to: :participant
  delegate :start, :finish, :target_amount, :duration_in_days, to: :challenge_story

  def initialize(participant, today = Time.zone.today)
    @participant = participant
    @today = today
  end

  def available?
    challenge_story.total? && today.between?(start, finish) && total_amount.positive?
  end

  def reached?
    total_amount >= target_amount
  end

  # The day the average reaches the target, or nil if that's after the end
  def reach_on
    day = start + (target_amount / daily_average).ceil - 1
    day if day <= finish
  end

  def projected_total
    daily_average * duration_in_days
  end

  private

  def daily_average
    total_amount / days_so_far
  end

  def days_so_far
    ((today - start).to_i + 1).clamp(1, duration_in_days)
  end
end
