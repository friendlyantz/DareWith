class TodayController < ApplicationController
  before_action :require_current_user!

  def show
    @challenge_stories = current_user.active_challenge_stories
      .includes(active_participants: [{user: {avatar_attachment: :blob}}, :todays_check_ins, :check_in_days, {recent_nudges: {sender: {user: {avatar_attachment: :blob}}}}])
      .order(:finish)
      .select(&:accepting_check_ins?)
    @upcoming_challenge_stories, @challenge_stories = @challenge_stories.partition { !it.started? }

    @done_count = @challenge_stories.count { it.participant_for(current_user).done_for_now? }
    @round_invites = current_user.next_round_invites
    @just_finished = current_user.just_finished_challenge_stories
  end
end
