# frozen_string_literal: true

module Webauthn
  class SessionsController < ApplicationController
    def new
    end

    # The browser offers every passkey it holds for this site, and the one picked says whose it is
    def create
      get_options = WebAuthn::Credential.options_for_get(user_verification: "required")
      session[:current_authentication] = {challenge: get_options.challenge}

      render json: get_options
    end

    def callback
      webauthn_credential = WebAuthn::Credential.from_get(params)
      raise "sign in was never started" unless session[:current_authentication]

      credential = Credential.on_this_domain.find_by(external_id: Base64.urlsafe_encode64(webauthn_credential.raw_id, padding: false))
      return render json: "That passkey isn't for #{Rails.configuration.app_host}", status: :unprocessable_content unless credential
      return render json: "That passkey belongs to another account", status: :unprocessable_content unless made_for?(credential.user, webauthn_credential)

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

    # The passkey must say it was made for the account it's saved against
    def made_for?(user, webauthn_credential)
      webauthn_credential.user_handle.nil? || webauthn_credential.user_handle == user.webauthn_id
    end
  end
end
