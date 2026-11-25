module ShareCardsHelper
  # What the progress card says, drawn in the browser by share_card_controller.js
  def share_card_values(participant)
    challenge_story = participant.challenge_story
    goal = challenge_story.goal
    headline, caption, emoji = share_card_headline(participant)
    penalty_caption, penalty = share_card_penalty(challenge_story)
    photo = participant.latest_photo_check_in&.photo
    url = challenge_story_share_url(challenge_story.share_code)

    {
      title: challenge_story.title,
      name: participant.name,
      headline:,
      caption:,
      emoji:,
      progress_label: goal.progress_label,
      progress: share_card_progress(participant),
      penalty_caption:,
      penalty:,
      url:,
      qr_code: share_card_qr_code(url),
      photo_url: photo && cl_image_path(photo.key, width: 1080, height: 1920, crop: :fill, secure: true)
    }
  end

  private

  # Rows of 1s and 0s, which the card draws as squares, so it stays sharp and can't taint the canvas
  def share_card_qr_code(url)
    RQRCode::QRCode.new(url, level: :m).modules.map { |row| row.map { it ? 1 : 0 }.join }
  end

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

  # "Every day I miss, everyone else gets" coffee: what friends who join stand to collect
  def share_card_penalty(challenge_story)
    return [] unless challenge_story.penalty_mode

    miss = challenge_story.per_miss? ? "Every #{challenge_story.goal.period_name} I miss" : "If I miss the most"
    ["#{miss}, everyone else gets", challenge_story.penalty]
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
