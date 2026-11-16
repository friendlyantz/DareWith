class Admin::SignInLinksController < Admin::ApplicationController
  # The link is shown once, to send by hand; it works like the emailed one (24 hours, single use)
  def create
    @user = User.find(params[:user_id])
    @sign_in_url = verify_email_session_url(token: @user.generate_email_login_token!(emailed: false))

    render "admin/users/show"
  end
end
