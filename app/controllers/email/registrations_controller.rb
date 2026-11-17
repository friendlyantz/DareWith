# frozen_string_literal: true

module Email
  class RegistrationsController < Email::ApplicationController
    def new
    end

    def create
      @signing_up = true
      return render_error("Email can't be blank") if normalized_email.blank?

      # Taken email: sign its owner in instead, so the form doesn't reveal who has an account
      existing = User.find_by(email: normalized_email)
      return send_sign_in_email(existing) if existing

      user = User.new(email: normalized_email, username: params.dig(:session, :username)&.strip)
      return render_error(user.errors.full_messages.to_sentence) unless user.save

      send_sign_in_email(user)
    end

    private

    def render_error(message)
      @error = message
      render :new, status: :unprocessable_content
    end
  end
end
