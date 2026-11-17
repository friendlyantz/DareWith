# frozen_string_literal: true

module Email
  class ApplicationController < ::ApplicationController
    private

    # Email a code and a sign-in link, then show the code box
    def send_sign_in_email(user)
      session[:email_sign_in_user_id] = user.id
      @email_sent = true

      if user.email_login_recently_sent?
        @error = "An email was recently sent. Use the code from it, or wait 15 minutes for a new one."
        return render "email/sessions/new", status: :too_many_requests
      end

      token = user.generate_email_login_token!
      code = user.generate_email_login_code!
      UserMailer.magic_link_email(user, token, code, session[:return_to]).deliver_later

      render "email/sessions/new"
    end

    def normalized_email
      params.dig(:session, :email)&.strip&.downcase
    end
  end
end
