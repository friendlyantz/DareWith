class Admin::ChallengeStoriesController < Admin::ApplicationController
  def destroy
    challenge_story = ChallengeStory.find(params[:id])
    challenge_story.destroy!

    redirect_to admin_root_path, status: :see_other, notice: "Deleted \"#{challenge_story.title}\""
  end
end
