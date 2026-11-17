class ChallengeStoriesController < ApplicationController
  before_action :require_current_user!, except: %i[index show]
  before_action :set_challenge_story, only: %i[edit update complete]
  before_action :set_previous_challenge_story, only: %i[new create]
  before_action :redirect_to_existing_next_round, only: %i[new create]

  def index
    return @challenge_stories = ChallengeStory.none unless current_user

    @challenge_stories = ChallengeStory
      .joins(:challenge_participants)
      .where(challenge_participants: {user_id: current_user.id, status: :active})
      .includes({active_participants: {user: {avatar_attachment: :blob}}}, challenge_check_ins: {photo_attachment: :blob})
      .left_joins(:challenge_check_ins)
      .group("challenge_stories.id")
      .order(Arel.sql("MAX(challenge_check_ins.created_at) DESC NULLS LAST, challenge_stories.updated_at DESC"))

    # Preload current user's participations to avoid N+1 in views
    story_ids = @challenge_stories.map(&:id)
    @user_participations = ChallengeParticipant
      .where(challenge_story_id: story_ids, user_id: current_user.id)
      .index_by(&:challenge_story_id)
  end

  def show
    remember_location unless current_user
    @challenge_story = ChallengeStory
      .includes(
        active_participants: [{user: [{avatar_attachment: :blob}, :web_push_notifications]}, :todays_check_ins, :check_in_days, {recent_nudges: {sender: {user: {avatar_attachment: :blob}}}}],
        challenge_rewards: [{giver: :user}, {receiver: :user}],
        challenge_check_ins: [{challenge_participant: {user: {avatar_attachment: :blob}}}, :challenge_check_in_likes, {challenge_check_in_replies: {user: {avatar_attachment: :blob}}}, {challenge_check_in_doubts: :user}, photo_attachment: :blob]
      )
      .find(params[:id])

    @current_challenge_participant = @challenge_story.participant_for(current_user) if current_user
  end

  def new
    @template = ChallengeStory::Template.find(params[:template]) unless @previous_challenge_story
    @challenge_story = @previous_challenge_story&.next_round ||
      @template&.build ||
      ChallengeStory.new(start: Time.zone.today, finish: Time.zone.today + 7.days)
  end

  def edit
  end

  def create
    @challenge_story = ChallengeStory.new(challenge_story_params)
    @challenge_story.previous_challenge_story = @previous_challenge_story

    if @challenge_story.save
      @challenge_story.find_or_activate_participant!(current_user)
      @challenge_story.invite_to_next_round(by: current_user) if @previous_challenge_story
      redirect_to @challenge_story, notice: "Challenge created"
    else
      render :new, status: :unprocessable_content
    end
  end

  def update
    if @challenge_story.update(challenge_story_params)
      redirect_to @challenge_story, notice: "Challenge updated", status: :see_other
    else
      render :edit, status: :unprocessable_content
    end
  end

  def complete
    @challenge_story.mark_complete!(by: current_user)
    redirect_to challenge_story_path(@challenge_story), notice: "Challenge completed for everyone"
  end

  private

  def set_challenge_story
    @challenge_story = current_user.challenge_stories.merge(ChallengeParticipant.active).find(params.expect(:id))
  end

  # Only someone who took part can start the next round
  def set_previous_challenge_story
    return if params[:previous_challenge_story_id].blank?

    @previous_challenge_story = current_user.challenge_stories.find(params[:previous_challenge_story_id])
  end

  def redirect_to_existing_next_round
    next_round = @previous_challenge_story&.next_challenge_story
    redirect_to next_round, notice: "Round #{next_round.round} has already started" if next_round
  end

  def challenge_story_params
    params.expect(challenge_story: [:title, :description, :start, :finish, :cadence, :times_per_period, :unit, :target_amount, :target_scope, :penalty_mode, :penalty])
  end
end
