module ShareCardsHelper
  # What the progress card says, drawn in the browser by share_card_controller.js
  def share_card_values(participant)
    challenge_story = participant.challenge_story
    goal = challenge_story.goal
    headline, caption, emoji = share_card_headline(participant)
    photo = participant.latest_photo_check_in&.photo

    {
      title: challenge_story.title,
      name: participant.name,
      headline:,
      caption:,
      emoji:,
      progress_label: goal.progress_label,
      progress: share_card_progress(participant),
      url: challenge_story_share_url(challenge_story.share_code),
      photo_url: photo && cl_image_path(photo.key, width: 1080, height: 1920, crop: :fill, secure: true)
    }
  end

  private

  # The one big number: total toward a target, a running streak, the amount so far, or periods kept
  def share_card_headline(participant)
    challenge_story = participant.challenge_story
    goal = challenge_story.goal
    streak = participant.streak.current

    if challenge_story.total?
      ["#{goal.format_number(participant.total_amount)} / #{goal.format_amount(challenge_story.target_amount)}", "toward the target"]
    elsif streak > 1
      [streak.to_s, "#{goal.period_name.pluralize(streak)} in a row", "🔥"]
    elsif goal.measured?
      [goal.format_amount(participant.total_amount), "so far"]
    else
      [participant.periods_kept.to_s, "#{goal.period_name.pluralize(participant.periods_kept)} kept"]
    end
  end

  def share_card_progress(participant)
    challenge_story = participant.challenge_story
    goal = challenge_story.goal
    fraction = if challenge_story.total?
      participant.total_amount / challenge_story.target_amount
    else
      goal.current_period_number.fdiv(goal.period_count)
    end

    fraction.to_f.clamp(0, 1).round(3)
  end
end
