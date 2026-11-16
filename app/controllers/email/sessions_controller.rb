# frozen_string_literal: true

module Email
  class SessionsController < ApplicationController
    rate_limit to: 10, within: 1.minute, only: :confirm

    def new
      # GET request - show the email sign-in form
    end

    def create
      email = session_params[:email]&.strip&.downcase
      username = session_params[:username]&.strip

      # Find or initialize user
      user = User.find_or_initialize_by(email: email) do |u|
        u.username = username || generate_username_from_email(email)
      end

      # Validate before proceeding
      unless user.valid?
        @error = user.errors.full_messages.join(", ")
        render :new, status: :unprocessable_content
        return
      end

      # Rate limiting
      if user.persisted? && user.email_login_recently_sent?
        session[:email_sign_in_user_id] = user.id
        @email_sent = true
        @error = "An email was recently sent. Use the code from it, or wait 15 minutes for a new one."
        render :new, status: :too_many_requests
        return
      end

      # Save new users
      user.save! if user.new_record?

      # Generate and send magic link, plus a code to type in this browser
      token = user.generate_email_login_token!
      code = user.generate_email_login_code!
      session[:email_sign_in_user_id] = user.id
      UserMailer.magic_link_email(user, token, code, session[:return_to]).deliver_later

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

    def session_params
      params.require(:session).permit(:email, :username)
    end

    def generate_username_from_email(email)
      base = email.split("@").first.gsub(/[^a-z0-9]/i, "")
      username = base
      counter = 1

      while User.exists?(username: username)
        username = "#{base}#{counter}"
        counter += 1
      end

      username
    end
  end
end
