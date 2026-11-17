class ChallengeCompletionJob < ApplicationJob
  # The last time zone to finish a day, so the grace day is over for everyone, wherever they are
  LAST_TIME_ZONE = "Etc/GMT+12"

  def perform
    Time.use_zone(LAST_TIME_ZONE) do
      ChallengeStory.active.where(finish: ...1.day.ago.to_date).find_each do |challenge_story|
        challenge_story.charge_penalties!
        challenge_story.mark_complete! if challenge_story.ready_to_auto_complete?
      rescue => err
        Rails.error.report(err, handled: true)
      end
    end
  end
end
