# frozen_string_literal: true

# Lines up the next round of a repeating challenge on its last day, starting the day after it ends.
# Everyone still in carries over and hears about it, so staying in is the default and leaving opts out.
class ChallengeStory::Repeat
  private attr_reader :challenge_story

  def initialize(challenge_story)
    @challenge_story = challenge_story
  end

  def start!
    round = challenge_story.next_round(start: challenge_story.finish + 1.day)

    ChallengeStory.transaction do
      round.save!
      participants.each { round.challenge_participants.create!(user: it.user, status: :active) }
    end
    announce(round)
    round
  end

  private

  def participants
    @participants ||= challenge_story.active_participants.includes(:user).to_a
  end

  def announce(round)
    participants.each do |participant|
      participant.user.notify(
        title: "Round #{round.round} of #{round.title} starts tomorrow",
        body: "You're in, same rules. Staying in? Leave the round if not.",
        path: Rails.application.routes.url_helpers.challenge_story_path(round)
      )
    end
  end
end
