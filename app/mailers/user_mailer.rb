# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "noreply@darewith.app")

  def magic_link_email(user, token, code = nil, return_to = nil)
    @user = user
    @token = token
    @code = code
    @magic_link_url = verify_email_session_url({token:, return_to:}.compact)

    mail(to: user.email, subject: code ? "#{code} is your DareWith sign-in code" : "Your DareWith Sign In Link")
  end

  # For an email with no account yet: the code or link proves it's theirs, then they pick a username
  def signup_email(signup, code, return_to = nil)
    @code = code
    @signup_url = verify_email_registration_url({token: signup.link_token, return_to:}.compact)

    mail(to: signup.email, subject: "#{code} is your code to join DareWith")
  end
end
