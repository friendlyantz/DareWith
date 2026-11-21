# frozen_string_literal: true

class User < ApplicationRecord
  CREDENTIAL_MIN_AMOUNT = 1
  EMAIL_TOKEN_EXPIRY = 24.hours
  EMAIL_CODE_EXPIRY = 15.minutes
  MAX_EMAIL_CODE_ATTEMPTS = 5
  REMINDER_HOURS = (6..22).to_a
  WEEKLY_RECAP_HOUR = 18
  ADMIN_USERNAMES = %w[friendlyantz].freeze
  PAYMENT_LINK = %r{\A(https?://)?([\w-]+\.)+[a-z]{2,}/\S+\z}i

  # Associations
  has_many :credentials, -> { on_this_domain }, dependent: :destroy
  has_many :challenge_story_likes, dependent: :destroy
  has_many :liked_challenge_stories, through: :challenge_story_likes, source: :challenge_story
  has_many :challenge_participants, dependent: :destroy
  has_many :challenge_stories, through: :challenge_participants
  has_many :challenge_check_ins, through: :challenge_participants
  has_many :web_push_notifications, dependent: :destroy
  has_many :notifications, dependent: :delete_all
  has_many :badges, dependent: :destroy
  has_many :challenge_check_in_replies, dependent: :destroy
  has_one_attached :avatar

  # Normalization
  normalizes :payment_details, with: ->(details) { details.strip.presence }

  # Validations
  validates :username, presence: true, uniqueness: true,
    length: {minimum: 3, maximum: 20},
    format: {
      with: /\A[a-zA-Z0-9_-]+\z/,
      message: "can only contain letters, numbers, underscores, and hyphens"
    }
  validates :email, presence: false, uniqueness: {allow_nil: true}, format: {with: URI::MailTo::EMAIL_REGEXP, allow_nil: true}
  validates :reminder_hour, inclusion: {in: 0..23}, allow_nil: true
  validates :time_zone, presence: true
  validates :payment_details, length: {maximum: 120}
  validate :avatar_is_a_small_image

  # Callbacks
  after_initialize do
    self.webauthn_id ||= WebAuthn.generate_user_id
  end

  # Public methods
  def admin?
    ADMIN_USERNAMES.include?(username.downcase)
  end

  def can_delete_credentials?
    credentials.size > CREDENTIAL_MIN_AMOUNT
  end

  # Their passkeys were made on an old domain, so none of them work here
  def passkeys_left_on_old_domain?
    credentials.none? && Credential.where(user_id: id).exists?
  end

  # One passkey that can't sync: losing that device locks them out
  def needs_backup_passkey?
    credentials.size == 1 && credentials.first.backed_up == false
  end

  # A paypal.me / revolut.me style link; nil for plain text such as a PayID
  def payment_url
    return unless payment_details.present? && PAYMENT_LINK.match?(payment_details)

    payment_details.start_with?("http") ? payment_details : "https://#{payment_details}"
  end

  def reminder_due?(now = Time.current)
    return false if reminder_hour.nil?

    local_now = now.in_time_zone(time_zone)
    local_now.hour == reminder_hour && last_reminded_on != local_now.to_date
  end

  def challenges_to_check_in_today
    Time.use_zone(time_zone) do
      active_challenge_stories.includes(active_participants: [:user, :todays_check_ins, :check_in_days, :recent_nudges]).select do |challenge_story|
        participant = challenge_story.participant_for(self)
        challenge_story.accepting_check_ins? &&
          challenge_story.started? &&
          participant.reminder_due_today? &&
          !participant.nudged_today?
      end
    end
  end

  def remind_to_check_in(now = Time.current)
    return unless reminder_due?(now)

    update!(last_reminded_on: now.in_time_zone(time_zone).to_date)
    challenge_stories = challenges_to_check_in_today
    return if challenge_stories.empty?

    title = challenge_stories.any?(&:penalty_mode) ? "Check in today or it's a miss" : "Still time to check in"
    notify(title:, body: challenge_stories.map(&:title).to_sentence, path: "/today")
  end

  def weekly_recap_due?(now = Time.current)
    local_now = now.in_time_zone(time_zone)
    local_now.sunday? && local_now.hour == WEEKLY_RECAP_HOUR && last_recapped_on != local_now.to_date
  end

  def send_weekly_recap(now = Time.current)
    return unless weekly_recap_due?(now)

    today = now.in_time_zone(time_zone).to_date
    update!(last_recapped_on: today)
    recap = WeeklyRecap.new(self, today)
    return unless recap.any?

    notify(title: recap.title, body: recap.body, path: "/today")
  end

  def push_enabled?
    web_push_notifications.any?
  end

  # Creating, joining or checking in all make a participant, so there's someone to hear from
  def in_a_challenge?
    challenge_participants.exists?
  end

  def notify(title:, body: nil, path: "/")
    notifications.create!(title:, body:, path:)
    web_push_notifications.each do |subscription|
      PushNotificationJob.perform_later(subscription, title:, body:, path:)
    end
  end

  def unread_notifications_count
    notifications.unread.count
  end

  def read_notifications!
    notifications.unread.update_all(read_at: Time.current)
  end

  def liked_friends_check_ins_count
    ChallengeCheckInLike
      .where(user: self)
      .joins(challenge_check_in: :challenge_participant)
      .where.not(challenge_participants: {user_id: id})
      .count
  end

  # Next rounds of challenges the user took part in, still open to join
  def next_round_invites
    ChallengeStory.active
      .where(finish: (Time.zone.today - 1.day)..)
      .where(previous_challenge_story_id: challenge_participants.active.select(:challenge_story_id))
      .where.not(id: challenge_participants.select(:challenge_story_id))
      .includes(active_participants: {user: {avatar_attachment: :blob}})
      .reject(&:at_capacity?)
  end

  # Ended in the last week, completed or not, so Today can point to the finale
  def just_finished_challenge_stories
    challenge_stories
      .merge(ChallengeParticipant.active)
      .where(finish: (Time.zone.today - ChallengeStory::JUST_FINISHED_FOR)...Time.zone.today)
      .order(finish: :desc)
      .includes(:active_participants)
      .reject(&:accepting_check_ins?)
  end

  def past_challenge_stories
    challenge_stories.merge(ChallengeStory.completed)
  end

  def active_challenge_stories
    challenge_stories
      .merge(ChallengeParticipant.active)
      .merge(ChallengeStory.active)
  end

  # Email authentication methods
  def generate_email_login_token!(emailed: true)
    raw_token = SecureRandom.urlsafe_base64(32)

    update!(
      email_login_token: Digest::SHA256.hexdigest(raw_token),
      email_login_token_expires_at: EMAIL_TOKEN_EXPIRY.from_now,
      last_email_sent_at: emailed ? Time.current : last_email_sent_at
    )

    raw_token
  end

  def verify_email_login_token(raw_token)
    return false if email_login_token.blank?
    return false if email_login_token_expires_at.blank?
    return false if email_login_token_expires_at < Time.current

    hashed_provided = Digest::SHA256.hexdigest(raw_token)
    hashed_provided == email_login_token
  end

  # A code to type in the same browser, for in-app browsers where the link opens elsewhere
  def generate_email_login_code!
    code = format("%06d", SecureRandom.random_number(1_000_000))
    update!(email_login_code_digest: Digest::SHA256.hexdigest(code), email_login_code_attempts: 0)
    code
  end

  # Wrong guesses are counted, so a code can't be brute-forced
  def verify_email_login_code(code)
    return false if email_login_code_digest.blank?
    return false if email_login_code_attempts >= MAX_EMAIL_CODE_ATTEMPTS
    return false unless last_email_sent_at&.after?(EMAIL_CODE_EXPIRY.ago)

    return true if ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(code.to_s.gsub(/\D/, "")), email_login_code_digest)

    self.class.update_counters(id, email_login_code_attempts: 1)
    false
  end

  def clear_email_login_token!
    update!(email_login_token: nil, email_login_token_expires_at: nil, email_login_code_digest: nil)
  end

  def self.find_by_email_login_token(raw_token)
    hashed_token = Digest::SHA256.hexdigest(raw_token)
    find_by(email_login_token: hashed_token)
  end

  def email_verified?
    email_verified_at.present?
  end

  def verify_email!
    update!(email_verified_at: Time.current)
  end

  private

  def avatar_is_a_small_image
    return unless avatar.attached?

    errors.add(:avatar, "must be an image") unless avatar.blob.content_type.to_s.start_with?("image/")
    errors.add(:avatar, "is too large (maximum 10MB)") if avatar.blob.byte_size > 10.megabytes
  end
end
