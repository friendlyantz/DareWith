class ChallengeCheckInsController < ApplicationController
  include ActionView::RecordIdentifier

  before_action :require_current_user!
  before_action :set_challenge_story, only: %i[new create]
  before_action :ensure_participant, only: %i[new create]

  def index
    @challenge_stories = ChallengeStory.where(
      id: current_user.challenge_participants.select(:challenge_story_id)
    ).active

    @challenge_check_ins = ChallengeCheckIn
      .joins(:challenge_story)
      .where(challenge_story_id: @challenge_stories.select(:id))
      .includes(:challenge_story, {challenge_participant: {user: {avatar_attachment: :blob}}}, :challenge_check_in_likes, photo_attachment: :blob)
      .order(created_at: :desc)
      .limit(20)
  end

  def new
    @challenge_check_in = ChallengeCheckIn.new(challenge_story_id: @challenge_story.id)
  end

  def create
    if @challenge_story.completed?
      return redirect_to challenge_story_path(@challenge_story),
        alert: "Cannot add check-ins to completed challenges"
    end

    @challenge_participant = @challenge_story.find_or_activate_participant!(current_user)
    @challenge_check_in = @challenge_participant.challenge_check_ins.build(challenge_check_in_params)
    @challenge_check_in.challenge_story = @challenge_story

    if @challenge_check_in.save
      @challenge_check_in.notify_other_participants
      render :success, status: :ok
    else
      render :new, status: :unprocessable_content
    end
  end

  def destroy
  end

  private

  def set_challenge_story
    @challenge_story = ChallengeStory.find(params[:challenge_story_id])
  end

  def ensure_participant
    return if @challenge_story.active_participants.exists?(user: current_user)

    redirect_to challenge_story_path(@challenge_story), alert: "You must be a participant to check in"
  end

  def challenge_check_in_params
    params.expect(challenge_check_in: %i[message photo])
  end
end
