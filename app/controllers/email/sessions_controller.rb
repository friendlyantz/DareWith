# frozen_string_literal: true

module Email
  class SessionsController < Email::ApplicationController
    rate_limit to: 10, within: 1.minute, only: :confirm

    def new
      # GET request - show the email sign-in form
    end

    def create
      user = User.find_by(email: normalized_email)
      return send_sign_in_email(user) if user

      # Same answer as for a real account, so it doesn't reveal who has one
      session.delete(:email_sign_in_user_id)
      @email_sent = true
      render :new
    end

    def verify
      token = params[:token]

      if token.blank?
        redirect_to new_webauthn_session_path, alert: "Invalid sign-in link"
        return
      end

      user = User.find_by_email_login_token(token)

      if user.nil?
        redirect_to new_webauthn_session_path, alert: "Invalid or expired sign-in link"
        return
      end

      unless user.verify_email_login_token(token)
        redirect_to new_webauthn_session_path, alert: "This sign-in link has expired"
        return
      end

      # The link may open in another browser, so it carries the invite
      remember_location(params[:return_to]) if params[:return_to].present?
      complete_sign_in(user)
    end

    def confirm
      user = User.find_by(id: session[:email_sign_in_user_id])
      return redirect_to new_email_session_path, alert: "Ask for a new code" unless user

      unless user.verify_email_login_code(params[:code])
        @email_sent = true
        @error = "That code didn't work. Check the email or ask for a new one."
        return render :new, status: :unprocessable_content
      end

      session.delete(:email_sign_in_user_id)
      complete_sign_in(user)
    end

    private

    def complete_sign_in(user)
      user.clear_email_login_token!
      user.verify_email!
      sign_in(user)

      redirect_to after_sign_in_path, notice: "Signed in successfully!"
    end
  end
end
