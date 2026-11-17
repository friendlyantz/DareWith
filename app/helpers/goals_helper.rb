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

  # "3 days in a row", "2 weeks in a row"
  def streak_phrase(count, challenge_story)
    "#{pluralize(count, challenge_story.goal.period_name)} in a row"
  end
end
