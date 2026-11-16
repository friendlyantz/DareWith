class HomeController < ApplicationController
  layout "hero"

  def index
    redirect_to today_path if current_user
  end
end
