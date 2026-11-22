# The numbers behind the admin dashboard: users, push devices, challenges and jobs
class Admin::Overview
  WEEK = 7.days
  CHART_DAYS = 14
  RECENT_USERS = 30

  # Users
  def users_count = User.count

  def new_users_count = User.where(created_at: WEEK.ago..).count

  def active_users_count
    ChallengeParticipant.joins(:challenge_check_ins)
      .where(challenge_check_ins: {created_at: WEEK.ago..})
      .distinct.count(:user_id)
  end

  def recent_users
    User.order(created_at: :desc).limit(RECENT_USERS)
  end

  # Email signups: a row is deleted once the account exists, so every one left is unfinished
  def unfinished_email_signups = EmailSignup.order(created_at: :desc).limit(RECENT_USERS)

  def new_users_with_email_count = User.where.not(email: nil).where(created_at: WEEK.ago..).count

  def passkeys_by_user = @passkeys_by_user ||= Credential.on_this_domain.group(:user_id).count

  def devices_by_user = @devices_by_user ||= WebPushNotification.group(:user_id).count

  def last_check_in_by_user
    @last_check_in_by_user ||= ChallengeCheckIn.joins(:challenge_participant)
      .group("challenge_participants.user_id")
      .maximum(:checked_in_on)
  end

  # Push notifications
  def devices_count = WebPushNotification.count

  def users_with_push_count = devices_by_user.size

  def reminders_on_count = User.where.not(reminder_hour: nil).where(id: devices_by_user.keys).count

  def devices_by_label
    @devices_by_label ||= WebPushNotification.all.map(&:label).tally.sort_by { |_label, count| -count }
  end

  # Activity per day, over each user's own local day
  def check_ins_per_day
    days = (CHART_DAYS - 1).days.ago.to_date..Time.zone.today
    counts = ChallengeCheckIn.where(checked_in_on: days).group(:checked_in_on).count
    days.map { |day| [day, counts.fetch(day, 0)] }
  end

  def weekly_activity
    since = (WEEK.ago..)
    {
      "Check-ins" => ChallengeCheckIn.where(created_at: since).count,
      "Replies" => ChallengeCheckInReply.where(created_at: since).count,
      "Likes" => ChallengeCheckInLike.where(created_at: since).count,
      "Rewards pledged" => ChallengeReward.where(created_at: since).count,
      "Rewards received" => ChallengeReward.fulfilled.where(fulfilled_at: since).count,
      "Badges earned" => Badge.where(created_at: since).count
    }
  end

  # Challenges, matching ChallengeStory#accepting_check_ins?
  def running_challenges
    @running_challenges ||= ChallengeStory.active
      .where(start: ..Time.zone.today, finish: (Time.zone.today - 1.day)..)
      .order(:finish)
      .to_a
  end

  def upcoming_challenges_count = ChallengeStory.active.where(start: (Time.zone.today + 1.day)..).count

  def completed_challenges_count = ChallengeStory.completed.count

  # Background jobs: Solid Queue keeps finished jobs for a day, and only production has its tables
  def jobs_available?
    return @jobs_available if defined?(@jobs_available)

    @jobs_available = SolidQueue::Job.table_exists?
  end

  def pushes_sent_count
    SolidQueue::Job.where(class_name: "PushNotificationJob").where.not(finished_at: nil).count
  end

  def failed_jobs_count = SolidQueue::FailedExecution.count

  def recent_failed_jobs
    SolidQueue::FailedExecution.includes(:job).order(created_at: :desc).limit(5)
  end
end
