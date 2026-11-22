# frozen_string_literal: true

module Email
  # The last step of signing up with email: the email is proven theirs, so they pick a username
  class RegistrationsController < ApplicationController
    before_action :set_verified_signup, only: %i[new create]

    # Opening the link proves the email. Nothing is used up, so link previews are harmless.
    # It only works in the browser that asked for it, so a link forwarded to someone else
    # can't make them an account on the sender's email
    def verify
      signup = EmailSignup.find_by_link(params[:token])
      return redirect_to new_email_session_path, alert: "That link has expired or was already used. Ask for a new code." unless signup
      return render :other_browser, locals: {signup:}, status: :forbidden unless started_here?(signup)

      signup.verified!
      session[:verified_email_signup_id] = signup.id
      redirect_to new_email_registration_path
    end

    def new
      @user = User.new(email: @signup.email)
    end

    def create
      @user = @signup.create_user(username: params.dig(:user, :username)&.strip)
      return render :new, status: :unprocessable_content unless @user.persisted?

      session.delete(:verified_email_signup_id)
      sign_in(@user)
      redirect_to after_sign_in_path, notice: "Welcome to DareWith!"
    end

    private

    def started_here?(signup)
      signup.id.in?([session[:email_signup_id], session[:verified_email_signup_id]])
    end

    def set_verified_signup
      @signup = EmailSignup.find_by(id: session[:verified_email_signup_id])
      redirect_to new_email_session_path, alert: "Enter your email to get a code first" unless @signup
    end
  end
end
