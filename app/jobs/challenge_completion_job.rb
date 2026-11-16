class ChallengeCompletionJob < ApplicationJob
  def perform
    ChallengeStory.active.where(finish: ...1.day.ago.to_date).find_each do |challenge_story|
      challenge_story.mark_complete! if challenge_story.ready_to_auto_complete?
    rescue => err
      Rails.error.report(err, handled: true)
    end
  end
end
