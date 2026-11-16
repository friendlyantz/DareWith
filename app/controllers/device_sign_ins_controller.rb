# The new device: shows a code and waits until a signed-in device approves it
class DeviceSignInsController < ApplicationController
  rate_limit to: 10, within: 10.minutes, only: :create

  def create
    device_sign_in = DeviceSignIn.create!(user_agent: request.user_agent)
    session[:device_sign_in_id] = device_sign_in.id

    redirect_to device_sign_in_path
  end

  def show
    @device_sign_in = DeviceSignIn.find_by(id: session[:device_sign_in_id])
    return redirect_to new_webauthn_session_path unless @device_sign_in

    user = @device_sign_in.claim!
    return unless user

    session.delete(:device_sign_in_id)
    sign_in(user)
    redirect_to after_device_sign_in_path, notice: "Signed in"
  end

  private

  # Offer a passkey for this device unless an invite link is waiting
  def after_device_sign_in_path
    session.delete(:return_to).presence || credentials_path
  end
end
