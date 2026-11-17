# frozen_string_literal: true

# What the slides say once a challenge's time is up: totals, a photo collage and who stood out
class ChallengeStory::Finale
  COLLAGE_SIZE = 6
  EARLY_BIRD_BEFORE_HOUR = 8
  NIGHT_OWL_FROM_HOUR = 21

  private attr_reader :challenge_story

  delegate :goal, to: :challenge_story

  def initialize(challenge_story)
    @challenge_story = challenge_story
  end

  def participants
    @participants ||= challenge_story.ranked_participants
  end

  def check_ins
    challenge_story.challenge_check_ins
  end

  def photos_count
    check_ins.count { it.photo.attached? }
  end

  def likes_count
    check_ins.sum(&:challenge_check_in_likes_count)
  end

  def replies_count
    check_ins.sum(&:challenge_check_in_replies_count)
  end

  def periods_kept
    participants.sum(&:periods_kept)
  end

  def total_amount
    participants.sum(&:total_amount)
  end

  def flawless?(participant)
    participant.periods_kept >= goal.period_count
  end

  # Spread across the whole challenge, oldest first, so the collage tells the story
  def collage
    photos = check_ins.select { it.photo.attached? }.sort_by(&:created_at)
    return photos if photos.size <= COLLAGE_SIZE

    Array.new(COLLAGE_SIZE) { photos[it * photos.size / COLLAGE_SIZE] }
  end

  def longest_streaker
    top_participant(minimum: 2) { it.streak.longest }
  end

  def most_liked_check_in
    check_in = check_ins.max_by(&:challenge_check_in_likes_count)
    check_in if check_in&.challenge_check_in_likes_count&.positive?
  end

  def early_bird
    most_check_ins_where { it < EARLY_BIRD_BEFORE_HOUR }
  end

  def night_owl
    most_check_ins_where { it >= NIGHT_OWL_FROM_HOUR }
  end

  # Most likes and replies on friends' check-ins
  def cheerleader
    cheers = check_ins.flat_map do |check_in|
      (check_in.challenge_check_in_likes + check_in.challenge_check_in_replies)
        .map(&:user_id).reject { it == check_in.challenge_participant.user_id }
    end.tally
    top_participant { cheers.fetch(it.user_id, 0) }
  end

  def photographer
    photos = check_ins.select { it.photo.attached? }.map(&:challenge_participant_id).tally
    top_participant(minimum: 2) { photos.fetch(it.id, 0) }
  end

  def comeback_kid
    participants.find { it.streak.comeback? }
  end

  # Settled or not, what each person is getting; withdrawn pledges are left out
  def rewards_for(participant)
    challenge_story.challenge_rewards.select { it.receiver_id == participant.id && !it.canceled? }
  end

  def rewards?
    participants.any? { rewards_for(it).any? }
  end

  def highlights?
    [longest_streaker, most_liked_check_in, early_bird, night_owl, cheerleader, photographer, comeback_kid].any?
  end

  private

  # Whoever scores highest, if they reach the minimum; ties go to the higher ranked
  def top_participant(minimum: 1, &score)
    participant = participants.max_by(&score)
    participant if participant && score.call(participant) >= minimum
  end

  def most_check_ins_where(&hour_matches)
    counts = check_ins.select { hour_matches.call(local_hour(it)) }.map(&:challenge_participant_id).tally
    top_participant { counts.fetch(it.id, 0) }
  end

  def local_hour(check_in)
    check_in.created_at.in_time_zone(check_in.challenge_participant.user.time_zone).hour
  end
end
