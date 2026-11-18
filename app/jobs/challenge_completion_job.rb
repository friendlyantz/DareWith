class ChallengeCompletionJob < ApplicationJob
  def perform
    Time.use_zone(ChallengeStory::LAST_TIME_ZONE) do
      ChallengeStory.active.where(finish: ...1.day.ago.to_date).find_each do |challenge_story|
        challenge_story.mark_complete!
      rescue => err
        Rails.error.report(err, handled: true)
      end
    end
  end
end
