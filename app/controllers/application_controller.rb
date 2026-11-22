class ApplicationController < ActionController::Base
  # Only allow modern browsers supporting webp images, web push, badges, import maps, CSS nesting, and CSS :has.
  allow_browser versions: :modern

  helper_method :current_user, :likely_webview?, :browser_handoff_url

  around_action :use_time_zone

  private

  # The browser sets a time_zone cookie, so "today" follows the user's own day
  def use_time_zone(&)
    browser_zone = ActiveSupport::TimeZone[cookies[:time_zone].to_s]
    if current_user && browser_zone && current_user.time_zone != browser_zone.tzinfo.name
      current_user.update_column(:time_zone, browser_zone.tzinfo.name)
    end

    Time.use_zone(current_user&.time_zone || browser_zone || "UTC", &)
  end

  # In-app browsers (Telegram, WhatsApp, Instagram...) can't use passkeys. Our own Android app can
  def likely_webview?
    return false if hotwire_native_app?

    ua = request.user_agent.to_s
    android_webview = /; ?wv\)/.match?(ua)
    ios_webview = /iPhone|iPad|iPod/.match?(ua) && !ua.include?("Safari")
    android_webview || ios_webview || cookies[:telegram_webview] == "true"
  end

  # The link to reopen in a real browser: the remembered invite if there is one
  def browser_handoff_url
    session[:return_to] ? request.base_url + session[:return_to] : request.original_url
  end

  def sign_in(user)
    session[:user_id] = user.id
  end

  def sign_out
    session[:user_id] = nil
  end

  def current_user
    @current_user ||=
      if session[:user_id]
        User.find_by(id: session[:user_id])
      end
  end

  def require_current_user!
    return if current_user.present?

    remember_location if request.get? || request.head?
    redirect_to new_webauthn_session_path
  end

  # Where to send a visitor back to once they sign in or sign up, e.g. an invite link
  def remember_location(path = request.fullpath)
    session[:return_to] = path if path.start_with?("/") && !path.start_with?("//")
  end

  # Someone not in any challenge yet (e.g. just signed up) starts by making one
  def after_sign_in_path
    return session.delete(:return_to) if session[:return_to].present?

    current_user.challenge_participants.none? ? new_challenge_story_path : root_path
  end
end
