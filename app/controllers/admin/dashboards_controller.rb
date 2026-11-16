class Admin::DashboardsController < Admin::ApplicationController
  def show
    @overview = Admin::Overview.new
  end
end
