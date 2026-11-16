# The signed-in device: enters or scans the new device's code and approves it
class DeviceSignInApprovalsController < ApplicationController
  before_action :require_current_user!
  rate_limit to: 20, within: 1.minute

  def new
    @code = params[:code]
    @device_sign_in = DeviceSignIn.find_pending(@code) if @code.present?
  end

  def create
    device_sign_in = DeviceSignIn.find_pending(params[:code])
    return redirect_to new_device_sign_in_approval_path, alert: "That code has expired. Get a new one on the other device." unless device_sign_in

    device_sign_in.approve!(current_user)
    redirect_to profile_path, notice: "#{device_sign_in.device_label.upcase_first} is signing in"
  end
end
