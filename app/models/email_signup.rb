# frozen_string_literal: true

# Someone proving an email is theirs before it has an account. No user exists until they
# pick a username, so the code they were emailed waits here, and the link is a signed token.
class EmailSignup < ApplicationRecord
  normalizes :email, with: -> { it.strip.downcase }

  validates :email, presence: true, uniqueness: true, format: {with: URI::MailTo::EMAIL_REGEXP}

  # The signup a link from the email was made for; nil once the account exists or the link expired
  def self.find_by_link(token)
    email = verifier.verified(token.to_s, purpose: :email_signup)
    find_by(email:) if email
  end

  def self.verifier
    Rails.application.message_verifier(:email_signup)
  end

  def generate_code!
    code = format("%06d", SecureRandom.random_number(1_000_000))
    update!(code_digest: Digest::SHA256.hexdigest(code), code_attempts: 0, code_sent_at: Time.current)
    code
  end

  def link_token
    self.class.verifier.generate(email, expires_in: User::EMAIL_TOKEN_EXPIRY, purpose: :email_signup)
  end

  # Wrong guesses are counted, so a code can't be brute-forced
  def verify_code(code)
    return false if code_attempts >= User::MAX_EMAIL_CODE_ATTEMPTS
    return false unless code_sent_at.after?(User::EMAIL_CODE_EXPIRY.ago)
    return true if ActiveSupport::SecurityUtils.secure_compare(Digest::SHA256.hexdigest(code.to_s.gsub(/\D/, "")), code_digest)

    self.class.update_counters(id, code_attempts: 1)
    false
  end

  # The account for this email, with its username; check persisted? for errors
  def create_user(username:)
    user = User.new(email:, username:, email_verified_at: Time.current)
    transaction { user.save && destroy! }
    user
  end
end
