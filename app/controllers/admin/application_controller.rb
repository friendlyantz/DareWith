class Admin::ApplicationController < ApplicationController
  before_action :require_admin!

  private

  # A plain 404 for everyone else, so the page doesn't reveal it exists
  def require_admin!
    head :not_found unless current_user&.admin?
  end
end
