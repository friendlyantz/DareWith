class Admin::ApplicationController < ApplicationController
  before_action :require_admin!

  private

  # The usual not-found page for everyone else, so it doesn't reveal the admin exists
  def require_admin!
    raise ActionController::RoutingError, "Not Found" unless current_user&.admin?
  end
end
