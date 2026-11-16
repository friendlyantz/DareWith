require "rails_helper"

RSpec.describe ChallengeCheckInReply, type: :model do
  let(:author) { create(:challenge_participant) }
  let(:story) { author.challenge_story }
  let(:check_in) { create(:challenge_check_in, challenge_participant: author) }
  let(:friend) { create(:challenge_participant, challenge_story: story) }

  it "trims the body and limits its length" do
    expect(build(:challenge_check_in_reply, body: "  hi  ").tap(&:validate).body).to eq "hi"
    expect(build(:challenge_check_in_reply, body: "   ")).not_to be_valid
    expect(build(:challenge_check_in_reply, body: "a" * 281)).not_to be_valid
  end

  describe "#notify_thread" do
    let!(:author_device) { create(:web_push_notification, user: author.user) }
    let!(:friend_device) { create(:web_push_notification, user: friend.user) }

    it "tells the author about a reply" do
      reply = create(:challenge_check_in_reply, challenge_check_in: check_in, user: friend.user, body: "How far?")

      expect { reply.notify_thread }
        .to have_enqueued_job(PushNotificationJob).exactly(:once)
        .with(author_device, title: "#{friend.user.username} replied to your check-in", body: "How far?", path: "/challenge_stories/#{story.id}#challenge_check_in_#{check_in.id}")
    end

    it "tells earlier repliers too, but never the one replying" do
      third = create(:challenge_participant, challenge_story: story)
      third_device = create(:web_push_notification, user: third.user)
      create(:challenge_check_in_reply, challenge_check_in: check_in, user: friend.user)
      reply = create(:challenge_check_in_reply, challenge_check_in: check_in, user: third.user)

      expect { reply.notify_thread }
        .to have_enqueued_job(PushNotificationJob).with(author_device, hash_including(title: "#{third.user.username} replied to your check-in"))
        .and have_enqueued_job(PushNotificationJob).with(friend_device, hash_including(title: "#{third.user.username} replied on #{author.user.username}'s check-in"))
      expect(PushNotificationJob).not_to have_been_enqueued.with(third_device, anything)
    end

    it "stays quiet when the author replies on their own check-in with no one else in the thread" do
      reply = create(:challenge_check_in_reply, challenge_check_in: check_in, user: author.user)

      expect { reply.notify_thread }.not_to have_enqueued_job(PushNotificationJob)
    end
  end

  describe "broadcasting" do
    let(:outsider) { create(:user) }

    before { check_in && friend }

    def feed_of(user) = "#{user.to_gid_param}:challenge_check_ins_feed"

    def create_reply = create(:challenge_check_in_reply, challenge_check_in: check_in, user: friend.user)

    it "appends to the challenge page and every participant's feed" do
      expect { create_reply }
        .to have_broadcasted_to(story.to_gid_param)
        .and have_broadcasted_to(feed_of(author.user))
        .and have_broadcasted_to(feed_of(friend.user))
    end

    it "does not reach users outside the challenge" do
      expect { create_reply }.not_to have_broadcasted_to(feed_of(outsider))
    end
  end
end
