# Some counters missed rows made around when the counter caches were added. Deleting a user
# or a challenge then takes one below zero and trips its check constraint, so count them again.
class RecountCounterCaches < ActiveRecord::Migration[8.1]
  def up
    execute <<~SQL
      UPDATE challenge_participants p SET
        given_rewards_count = (SELECT count(*) FROM challenge_rewards r WHERE r.giver_id = p.id),
        received_rewards_count = (SELECT count(*) FROM challenge_rewards r WHERE r.receiver_id = p.id),
        challenge_check_ins_count = (SELECT count(*) FROM challenge_check_ins c WHERE c.challenge_participant_id = p.id);

      UPDATE challenge_stories s SET
        challenge_participants_count = (SELECT count(*) FROM challenge_participants p WHERE p.challenge_story_id = s.id),
        challenge_check_ins_count = (SELECT count(*) FROM challenge_check_ins c WHERE c.challenge_story_id = s.id),
        challenge_rewards_count = (SELECT count(*) FROM challenge_rewards r WHERE r.challenge_story_id = s.id),
        challenge_story_likes_count = (SELECT count(*) FROM challenge_story_likes l WHERE l.challenge_story_id = s.id);

      UPDATE users u SET
        challenge_participants_count = (SELECT count(*) FROM challenge_participants p WHERE p.user_id = u.id),
        challenge_story_likes_count = (SELECT count(*) FROM challenge_story_likes l WHERE l.user_id = u.id),
        badges_count = (SELECT count(*) FROM badges b WHERE b.user_id = u.id),
        challenge_check_in_replies_count = (SELECT count(*) FROM challenge_check_in_replies r WHERE r.user_id = u.id);

      UPDATE challenge_check_ins c SET
        challenge_check_in_likes_count = (SELECT count(*) FROM challenge_check_in_likes l WHERE l.challenge_check_in_id = c.id),
        challenge_check_in_replies_count = (SELECT count(*) FROM challenge_check_in_replies r WHERE r.challenge_check_in_id = c.id);
    SQL
  end

  def down
  end
end
