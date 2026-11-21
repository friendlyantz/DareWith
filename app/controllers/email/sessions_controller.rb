# frozen_string_literal: true

module Email
  # One way in with email: a code for an existing account, or a code to start one.
  # The page looks the same either way, so it doesn't reveal who has an account.
  class SessionsController < ApplicationController
    rate_limit to: 3, within: 15.minutes, by: -> { normalized_email.to_s }, only: :create, name: "email", with: :too_many_emails
    rate_limit to: 20, within: 15.minutes, only: :create, name: "ip", with: :too_many_emails
    rate_limit to: 10, within: 1.minute, only: :confirm
    before_action :set_link_user, only: %i[verify redeem]

    def new
    end

    def create
      return render_error("That doesn't look like an email address") unless URI::MailTo::EMAIL_REGEXP.match?(normalized_email.to_s)

      user = User.find_by(email: normalized_email)
      return send_sign_in_email(user) if user

      send_signup_email
    end

    # Opening the link only shows a Sign in button: chat apps and mail scanners open links
    # to preview them, and that would use up the single-use token before the person taps it
    def verify
    end

    def redeem
      # The link may open in another browser, so it carries the invite
      remember_location(params[:return_to]) if params[:return_to].present?
      complete_sign_in(@user)
    end

    def confirm
      return confirm_signup_code if session[:email_signup_id]

      user = User.find_by(id: session[:email_sign_in_user_id])
      return redirect_to new_email_session_path, alert: "Ask for a new code" unless user
      return wrong_code unless user.verify_email_login_code(params[:code])

      session.delete(:email_sign_in_user_id)
      complete_sign_in(user)
    end

    private

    def send_sign_in_email(user)
      token = user.generate_email_login_token!
      code = user.generate_email_login_code!
      UserMailer.magic_link_email(user, token, code, session[:return_to]).deliver_later

      session.delete(:email_signup_id)
      session[:email_sign_in_user_id] = user.id
      show_code_box
    end

    def send_signup_email
      signup = EmailSignup.find_or_initialize_by(email: normalized_email)
      code = signup.generate_code!
      UserMailer.signup_email(signup, code, session[:return_to]).deliver_later

      session.delete(:email_sign_in_user_id)
      session[:email_signup_id] = signup.id
      show_code_box
    end

    # The email is theirs: next they pick a username
    def confirm_signup_code
      signup = EmailSignup.find_by(id: session[:email_signup_id])
      return redirect_to new_email_session_path, alert: "Ask for a new code" unless signup
      return wrong_code unless signup.verify_code(params[:code])

      session.delete(:email_signup_id)
      session[:verified_email_signup_id] = signup.id
      redirect_to new_email_registration_path
    end

    def show_code_box
      @email_sent = true
      render :new
    end

    def wrong_code
      @email_sent = true
      @error = "That code didn't work. Check the email or ask for a new one."
      render :new, status: :unprocessable_content
    end

    # Same limit whether or not the email has an account, so this doesn't reveal one either
    def too_many_emails
      @email_sent = session[:email_sign_in_user_id].present? || session[:email_signup_id].present?
      @error = "That's a lot of emails. Use the code from the last one, or try again in 15 minutes."
      render :new, status: :too_many_requests
    end

    def render_error(message)
      @error = message
      render :new, status: :unprocessable_content
    end

    def normalized_email
      params.dig(:session, :email)&.strip&.downcase
    end

    def set_link_user
      return redirect_to(new_webauthn_session_path, alert: "Invalid sign-in link") if params[:token].blank?

      @user = User.find_by_email_login_token(params[:token])
      return redirect_to(new_webauthn_session_path, alert: "Invalid or expired sign-in link") unless @user

      redirect_to(new_webauthn_session_path, alert: "This sign-in link has expired") unless @user.verify_email_login_token(params[:token])
    end

    def complete_sign_in(user)
      user.clear_email_login_token!
      user.verify_email!
      sign_in(user)

      redirect_to after_email_sign_in_path(user), notice: "Signed in successfully!"
    end

    # People whose passkeys stayed on the old domain go straight to adding a new one
    def after_email_sign_in_path(user)
      return after_sign_in_path unless user.passkeys_left_on_old_domain? && !likely_webview?

      session.delete(:return_to).presence || credentials_path
    end
  end
end
