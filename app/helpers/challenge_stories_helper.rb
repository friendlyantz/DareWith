module ChallengeStoriesHelper
  # "50 reps a day · 1 Dec – 31 Dec · 2 of 4 in · Get stronger before summer"
  def challenge_story_preview_description(challenge_story)
    [
      challenge_story.goal.summary || "Check in every day",
      "#{challenge_story.start.strftime("%-d %b")} – #{challenge_story.finish.strftime("%-d %b")}",
      "#{challenge_story.active_participants.size} of #{ChallengeStory::MAX_PARTICIPANTS} in",
      challenge_story.description.truncate(120)
    ].compact_blank.join(" · ")
  end

  # "Starts tomorrow", "Starts in 3 days"
  def starts_in(challenge_story)
    return "Starts tomorrow" if challenge_story.days_until_start == 1

    "Starts in #{pluralize(challenge_story.days_until_start, "day")}"
  end
end
