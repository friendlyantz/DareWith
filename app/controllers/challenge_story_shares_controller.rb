class ChallengeStorySharesController < ApplicationController
  def show
    redirect_to challenge_story_path(ChallengeStory.find_by!(share_code: params[:share_code]))
  end
end
