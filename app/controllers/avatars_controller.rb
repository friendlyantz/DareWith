class AvatarsController < ApplicationController
  before_action :require_current_user!

  def update
    if current_user.update(avatar_params)
      redirect_to profile_path, notice: "Photo updated"
    else
      redirect_to profile_path, alert: current_user.errors.full_messages_for(:avatar).to_sentence
    end
  end

  def destroy
    current_user.avatar.purge_later
    redirect_to profile_path, notice: "Photo removed"
  end

  private

  def avatar_params
    params.expect(user: [:avatar])
  end
end
