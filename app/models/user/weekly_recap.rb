# frozen_string_literal: true

# Sunday evening summary of the last seven days: your days, your best streak and how friends did
class User::WeeklyRecap
  FRIENDS_SHOWN = 3

  private attr_reader :user, :today

  def initialize(user, today = Time.zone.today)
    @user = user
    @today = today
  end

  def any?
    participants.any?
  end

  def title
    "Your week: #{days_checked_in} of #{possible_days} days"
  end

  def body
    [streak_line, friends_line].compact.join(". ")
  end

  private

  def week
    (today - 6.days)..today
  end

  def participants
    @participants ||= user.challenge_participants.active
      .joins(:challenge_story)
      .where(challenge_stories: {start: ..today, finish: week.first..})
      .includes(:challenge_story, :check_in_days)
      .to_a
  end

  def possible_days
    @possible_days ||= participants
      .flat_map { |participant| (participant.challenge_story.start..participant.challenge_story.finish).to_a }
      .uniq.count { |day| week.cover?(day) }
  end

  # A check-in on the grace day after the end can't push this past the days on offer
  def days_checked_in
    [days_in_week(participants), possible_days].min
  end

  def streak_line
    best = participants.max_by { |participant| participant.streak.current(today) }
    streak = best.streak.current(today)
    return "A new week starts tomorrow" if streak.zero?

    "🔥 #{streak}-day streak in #{best.challenge_story.title}"
  end

  def friends_line
    results = friends.group_by(&:user_id).values
      .map { |participations| [participations.first.name, days_in_week(participations)] }
      .reject { |_name, days| days.zero? }
      .sort_by { |name, days| [-days, name] }
      .first(FRIENDS_SHOWN)
    return if results.empty?

    results.map { |name, days| "#{name} #{days} #{"day".pluralize(days)}" }.to_sentence
  end

  def friends
    ChallengeParticipant.active
      .where(challenge_story_id: participants.map(&:challenge_story_id))
      .where.not(user_id: user.id)
      .includes(:check_in_days)
  end

  def days_in_week(participations)
    participations.flat_map(&:check_in_days).map(&:checked_in_on).uniq.count { |day| week.cover?(day) }
  end
end
