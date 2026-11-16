class Admin::UsersController < Admin::ApplicationController
  before_action :set_user

  def show
  end

  def destroy
    return redirect_to admin_user_path(@user), alert: "You can't delete yourself" if @user == current_user

    @user.destroy!
    redirect_to admin_root_path, notice: "Deleted #{@user.username}"
  end

  private

  def set_user
    @user = User.find(params[:id])
  end
end
