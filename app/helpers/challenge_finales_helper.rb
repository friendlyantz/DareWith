module ChallengeFinalesHelper
  # "27 of 30 days", or "80 / 100 km" for a "by the end" target
  def finale_score(participant)
    challenge_story = participant.challenge_story
    goal = challenge_story.goal
    return "#{goal.format_number(participant.total_amount)} / #{goal.format_amount(challenge_story.target_amount)}" if challenge_story.total?

    "#{participant.periods_kept} of #{pluralize(goal.period_count, goal.period_name)}"
  end

  def finale_fraction(participant)
    challenge_story = participant.challenge_story
    fraction = if challenge_story.total?
      participant.total_amount / challenge_story.target_amount
    else
      participant.periods_kept.fdiv(challenge_story.goal.period_count)
    end

    fraction.to_f.clamp(0, 1).round(3)
  end

  # "3 Nov – 2 Dec · 30 days"
  def finale_dates(challenge_story)
    "#{challenge_story.start.strftime("%-d %b")} – #{challenge_story.finish.strftime("%-d %b")} · #{pluralize(challenge_story.duration_in_days, "day")}"
  end

  # What the finish card says, drawn in the browser by finale_card_controller.js
  def finale_card_values(participant, finale)
    challenge_story = participant.challenge_story
    goal = challenge_story.goal
    stats = []
    stats << "Best streak: #{streak_phrase(participant.streak.longest, challenge_story)}" if participant.streak.longest > 1
    stats << "#{pluralize(finale.check_ins.size, "check-in")} together" if finale.participants.size > 1
    stats << "#{goal.format_amount(participant.total_amount)} in total" if goal.measured? && !challenge_story.total?

    {
      title: challenge_story.title,
      name: participant.name,
      headline: challenge_story.total? ? goal.format_number(participant.total_amount) : participant.periods_kept.to_s,
      caption: challenge_story.total? ? "of #{goal.format_amount(challenge_story.target_amount)}" : "of #{pluralize(goal.period_count, goal.period_name)} kept",
      emoji: "🎉",
      progress: finale_fraction(participant),
      stats: stats.first(2),
      url: challenge_story_url(challenge_story),
      photo_urls: finale.collage.map { cl_image_path(it.photo.key, width: 540, height: 540, crop: :fill, secure: true) }
    }
  end
end
