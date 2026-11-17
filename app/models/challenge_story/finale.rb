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
    participant = participants.max_by { it.streak.longest }
    participant if participant && participant.streak.longest > 1
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

  def highlights?
    [longest_streaker, most_liked_check_in, early_bird, night_owl].any?
  end

  private

  # The participant with the most check-ins at a local hour matching the block, if anyone has one
  def most_check_ins_where(&hour_matches)
    counts = check_ins.select { hour_matches.call(local_hour(it)) }.map(&:challenge_participant_id).tally
    participant = participants.max_by { counts.fetch(it.id, 0) }
    participant if participant && counts.key?(participant.id)
  end

  def local_hour(check_in)
    check_in.created_at.in_time_zone(check_in.challenge_participant.user.time_zone).hour
  end
end
