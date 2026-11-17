module GoalsHelper
  # "1 of 3 this week · 4 days left"
  def week_progress(participant)
    goal = participant.challenge_story.goal
    days_left = goal.days_left_in_period

    "#{participant.check_ins_this_period} of #{participant.challenge_story.times_per_period} this week · " +
      ((days_left == 1) ? "last day" : "#{days_left} days left")
  end

  def check_in_button_label(participant)
    challenge_story = participant.challenge_story
    return "Check in · day #{challenge_story.goal.current_period_number}" if challenge_story.daily?
    return "Check in · extra" if participant.period_kept?

    "Check in · #{participant.check_ins_this_period + 1} of #{challenge_story.times_per_period} this week"
  end

  # "Each miss: owe everyone a coffee"
  def penalty_summary(challenge_story)
    return unless challenge_story.penalty_mode

    "#{challenge_story.per_miss? ? "Each miss" : "Most misses"}: owe everyone #{challenge_story.penalty}"
  end

  # "2 misses · owes a coffee × 2". Most misses can still change hands until check-ins close.
  def misses_line(participant)
    challenge_story = participant.challenge_story
    owed = challenge_story.penalty_rule&.owed_by(participant)
    return unless owed

    still_open = challenge_story.most_misses? && challenge_story.accepting_check_ins?
    "#{pluralize(participant.misses, "miss")} · #{still_open ? "most so far" : "owes #{owed}"}"
  end

  # "At this pace: 100 km by 3 Dec", for "by the end" targets
  def forecast_line(participant)
    forecast = participant.forecast
    return unless forecast.available?

    goal = participant.challenge_story.goal
    return "Target reached 🎉" if forecast.reached?
    return "At this pace: #{goal.format_amount(participant.challenge_story.target_amount)} by #{forecast.reach_on.strftime("%-d %b")}" if forecast.reach_on

    "At this pace: #{goal.format_amount(forecast.projected_total.floor(goal.whole_numbers? ? 0 : 1))} by the end"
  end

  # "3 days in a row", "2 weeks in a row"
  def streak_phrase(count, challenge_story)
    "#{pluralize(count, challenge_story.goal.period_name)} in a row"
  end

  def freezes_phrase(freezes)
    "#{pluralize(freezes, "streak freeze")}: #{(freezes == 1) ? "covers a day" : "cover days"} you miss"
  end

  # "2 more days to earn a streak freeze", or nil for weekly challenges
  def freeze_progress_phrase(streak)
    freezes = streak.freezes
    days = streak.days_to_next_freeze

    if days.nil?
      "#{freezes} freezes ready: miss a day and your streak keeps going" if freezes.positive?
    elsif freezes.zero?
      "#{pluralize(days, "more day")} to earn a streak freeze"
    else
      "#{pluralize(freezes, "freeze")} · #{pluralize(days, "more day")} to earn another"
    end
  end
end
