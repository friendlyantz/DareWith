# frozen_string_literal: true

# Works out every badge a user has earned and stores the missing ones, so it's safe to run any number of times
class Badge::Awarder
  STREAK_DAYS = {three_day_streak: 3, week_streak: 7, three_week_streak: 21}.freeze
  FINISHER_SHARE = 0.8
  CHEERLEADER_LIKES = 10

  private attr_reader :user

  def initialize(user)
    @user = user
  end

  # Returns the newly earned badges
  def award
    owned = user.badges.pluck(:kind, :challenge_story_id).to_set

    earned
      .reject { |kind, challenge_story| owned.include?([kind.to_s, challenge_story&.id]) }
      .filter_map { |kind, challenge_story| create(kind, challenge_story) }
  end

  private

  def earned
    lifetime_kinds.map { [it, nil] } +
      participants.flat_map { |participant| challenge_kinds(participant).map { [it, participant.challenge_story] } }
  end

  def lifetime_kinds
    kinds = []
    kinds << :first_check_in if user.challenge_participants.sum(:challenge_check_ins_count).positive?
    kinds << :cheerleader if user.liked_friends_check_ins_count >= CHEERLEADER_LIKES
    kinds << :good_for_it if ChallengeReward.pledge.fulfilled.exists?(giver: user.challenge_participants)
    kinds
  end

  def challenge_kinds(participant)
    streak = participant.streak
    kinds = participant.challenge_story.daily? ? STREAK_DAYS.select { |_kind, days| streak.longest >= days }.keys : []
    kinds << :comeback if streak.comeback?
    kinds + completion_kinds(participant)
  end

  def completion_kinds(participant)
    challenge_story = participant.challenge_story
    return [] unless challenge_story.completed?

    share = participant.periods_kept.fdiv(challenge_story.goal.period_count)
    kinds = []
    kinds << :finisher if share >= FINISHER_SHARE
    kinds << :flawless if share >= 1
    kinds
  end

  def participants
    user.challenge_participants.active.includes(:challenge_story, :check_in_days)
  end

  def create(kind, challenge_story)
    user.badges.create!(kind:, challenge_story:)
  rescue ActiveRecord::RecordNotUnique
    nil
  end
end
