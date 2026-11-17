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
end
