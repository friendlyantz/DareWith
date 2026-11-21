# frozen_string_literal: true

# What missing costs, when a challenge sets a penalty. Either each miss costs it once,
# or whoever missed most owes it. It's owed to every friend in the challenge,
# and becomes penalty pledges that settle like rewards once check-ins close.
class ChallengeStory::Penalty
  private attr_reader :challenge_story

  delegate :penalty, :per_miss?, :active_participants, to: :challenge_story

  def initialize(challenge_story)
    @challenge_story = challenge_story
  end

  # "Each miss: coffee for everyone"
  def summary
    "#{per_miss? ? "Each miss" : "Most misses"}: #{penalty} for everyone"
  end

  # How many times the participant owes each friend the penalty, counting misses so far
  def times_owed_by(participant)
    return participant.misses if per_miss?

    worst_missers.include?(participant) ? 1 : 0
  end

  # "coffee", "coffee × 2", or nil when nothing's owed
  def owed_by(participant)
    times = times_owed_by(participant)
    return if times.zero?

    (times == 1) ? penalty : "#{penalty} × #{times}"
  end

  # Turns what's owed into penalty pledges, once check-ins have closed, and returns the new ones
  def charge!
    return [] if challenge_story.accepting_check_ins?

    active_participants.includes(:user, :check_in_days).flat_map do |participant|
      owed = owed_by(participant)
      next [] unless owed

      (active_participants - [participant]).filter_map do |friend|
        next if challenge_story.challenge_rewards.penalty.exists?(giver: participant, receiver: friend)

        challenge_story.challenge_rewards.create!(kind: :penalty, giver: participant, receiver: friend, description: owed)
      end
    end
  end

  private

  # Everyone tied for the most misses, unless that's everyone
  def worst_missers
    @worst_missers ||= begin
      misses = active_participants.index_with(&:misses)
      most = misses.values.max.to_i
      worst = misses.select { |_participant, count| count == most }.keys
      (most.zero? || worst.size == misses.size) ? [] : worst
    end
  end
end
