# frozen_string_literal: true

class UserMailer < ApplicationMailer
  default from: ENV.fetch("MAILER_FROM_ADDRESS", "noreply@strivo.me")

  def magic_link_email(user, token, code = nil, return_to = nil)
    @user = user
    @token = token
    @code = code
    @magic_link_url = verify_email_session_url({token:, return_to:}.compact)

    mail(to: user.email, subject: code ? "#{code} is your Strivo sign-in code" : "Your Strivo Sign In Link")
  end
end
