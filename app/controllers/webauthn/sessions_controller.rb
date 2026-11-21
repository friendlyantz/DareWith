# frozen_string_literal: true

module Webauthn
  class SessionsController < ApplicationController
    def new
    end

    # Without a username the browser offers every passkey it holds for this site
    def create
      return start_authentication if session_params[:username].blank?

      user = User.find_by(username: session_params[:username])

      if user&.passkeys_left_on_old_domain?
        render json: {errors: [moved_domain_message(user)]}, status: :unprocessable_content
      elsif user
        start_authentication(user)
      else
        render json: {errors: ["Username doesn't exist"]}, status: :unprocessable_content
      end
    end

    def callback
      webauthn_credential = WebAuthn::Credential.from_get(params)
      raise "sign in was never started" unless session[:current_authentication]

      credential = Credential.on_this_domain.find_by(external_id: Base64.urlsafe_encode64(webauthn_credential.raw_id, padding: false))
      return render json: "That passkey isn't for #{Rails.configuration.app_host}", status: :unprocessable_content unless credential
      return render json: "That passkey belongs to another account", status: :unprocessable_content unless started_by?(credential.user, webauthn_credential)

      begin
        webauthn_credential.verify(
          session[:current_authentication]["challenge"],
          public_key: credential.public_key,
          sign_count: credential.sign_count,
          user_verification: true
        )

        credential.update!(sign_count: webauthn_credential.sign_count, backed_up: webauthn_credential.backed_up?)
        sign_in(credential.user)

        render json: {status: "ok", redirect_to: after_sign_in_path}, status: :ok
      rescue WebAuthn::Error => e
        render json: "Verification failed: #{e.message}", status: :unprocessable_content
      ensure
        session.delete(:current_authentication)
      end
    end

    def destroy
      sign_out

      redirect_to root_path
    end

    # Test-only action for signing in without WebAuthn
    def test_sign_in
      raise "Not available outside test environment" unless Rails.env.test?

      user = User.find(params[:user_id])
      sign_in(user)
      redirect_to root_path
    end

    private

    def start_authentication(user = nil)
      get_options = WebAuthn::Credential.options_for_get(
        allow: user&.credentials&.pluck(:external_id),
        user_verification: "required"
      )

      session[:current_authentication] = {challenge: get_options.challenge, username: user&.username}

      render json: get_options
    end

    # The passkey must be for the username they typed, and the user it says it was made for
    def started_by?(user, webauthn_credential)
      username = session[:current_authentication]["username"]
      return false if username && username != user.username

      webauthn_credential.user_handle.nil? || webauthn_credential.user_handle == user.webauthn_id
    end

    # Without an email they can't sign in alone, so the admin sends them a sign-in link
    def moved_domain_message(user)
      moved = "We moved to #{Rails.configuration.app_host}, so your passkey needs replacing."
      return "#{moved} Sign in with email once, then add a new one." if user.email.present?

      "#{moved} Your account has no email, so ask whoever invited you to DareWith for a sign-in link."
    end

    def session_params
      params.fetch(:session, {}).permit(:username)
    end
  end
end
