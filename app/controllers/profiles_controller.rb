class ProfilesController < ApplicationController
  before_action :require_current_user!

  def show
    @active_challenges_count = current_user.active_challenge_stories.count
    @past_challenge_stories = current_user.past_challenge_stories.order(finish: :desc)
  end
end
