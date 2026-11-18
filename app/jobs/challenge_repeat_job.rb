class ChallengeRepeatJob < ApplicationJob
  def perform
    ChallengeStory.due_to_repeat.find_each do |challenge_story|
      challenge_story.repeat!
    rescue => err
      Rails.error.report(err, handled: true)
    end
  end
end
