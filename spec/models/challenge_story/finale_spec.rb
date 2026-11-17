require "rails_helper"

RSpec.describe ChallengeStory::Finale do
  let(:story) { create(:challenge_story, :finished) }
  let(:anna) { create(:challenge_participant, challenge_story: story, user: create(:user, username: "anna")) }
  let(:bob) { create(:challenge_participant, challenge_story: story, user: create(:user, username: "bob")) }

  def check_in(participant, days_from_start, *traits, hour: 12)
    create(:challenge_check_in, *traits, challenge_participant: participant, checked_in_on: story.start + days_from_start,
      created_at: (story.start + days_from_start).in_time_zone.change(hour:))
  end

  def finale
    ChallengeStory.find(story.id).finale
  end

  describe "#collage" do
    it "picks photos spread across the challenge, oldest first" do
      photos = Array.new(8) { check_in(anna, it, :with_photo) }
      check_in(anna, 1)

      expect(finale.collage.map(&:id)).to eq photos.sort_by(&:created_at).values_at(0, 1, 2, 4, 5, 6).map(&:id)
    end

    it "is empty without photos" do
      check_in(anna, 0)

      expect(finale.collage).to be_empty
    end
  end

  describe "#early_bird and #night_owl" do
    it "picks who checked in most often early or late, in their own time zone" do
      bob.user.update!(time_zone: "Pacific/Auckland")
      check_in(anna, 0, hour: 6)
      check_in(bob, 0, hour: 18) # 7am in Auckland
      check_in(bob, 1, hour: 17) # 6am in Auckland
      check_in(anna, 1, hour: 22)

      expect(finale.early_bird.name).to eq "bob"
      expect(finale.night_owl.name).to eq "anna"
    end

    it "is nobody when no one checked in at those hours" do
      check_in(anna, 0, hour: 12)

      expect(finale.early_bird).to be_nil
      expect(finale.night_owl).to be_nil
    end

    it "ignores people who left" do
      check_in(bob, 0, hour: 6)
      bob.leave!
      anna

      expect(finale.early_bird).to be_nil
    end
  end

  describe "#longest_streaker" do
    it "picks the longest run of kept days" do
      [0, 1, 2].each { check_in(anna, it) }
      [0, 2, 4].each { check_in(bob, it) }

      expect(finale.longest_streaker.name).to eq "anna"
    end

    it "is nobody when no one kept two days in a row" do
      check_in(anna, 0)

      expect(finale.longest_streaker).to be_nil
    end
  end

  describe "#most_liked_check_in" do
    it "is nobody without likes" do
      check_in(anna, 0)

      expect(finale.most_liked_check_in).to be_nil
    end

    it "picks the check-in with the most likes" do
      check_in(anna, 0)
      liked = check_in(bob, 1)
      create(:challenge_check_in_like, challenge_check_in: liked)

      expect(finale.most_liked_check_in).to eq liked
    end
  end

  describe "#cheerleader" do
    it "picks who liked and replied most on friends' check-ins, not their own" do
      annas = check_in(anna, 0)
      bobs = check_in(bob, 0)
      create(:challenge_check_in_like, challenge_check_in: annas, user: bob.user)
      create(:challenge_check_in_reply, challenge_check_in: annas, user: bob.user)
      create(:challenge_check_in_like, challenge_check_in: bobs, user: anna.user)
      create(:challenge_check_in_like, challenge_check_in: annas, user: anna.user)
      create(:challenge_check_in_reply, challenge_check_in: annas, user: anna.user)

      expect(finale.cheerleader.name).to eq "bob"
    end

    it "is nobody without likes or replies" do
      check_in(anna, 0)

      expect(finale.cheerleader).to be_nil
    end
  end

  describe "#photographer" do
    it "needs at least two photos" do
      check_in(anna, 0, :with_photo)

      expect(finale.photographer).to be_nil
    end

    it "picks who posted the most photos" do
      check_in(anna, 0, :with_photo)
      check_in(bob, 0, :with_photo)
      check_in(bob, 1, :with_photo)

      expect(finale.photographer.name).to eq "bob"
    end
  end

  describe "#comeback_kid" do
    it "picks someone who came back after missing a few days" do
      check_in(anna, 0)
      check_in(anna, 1)
      [0, 4].each { check_in(bob, it) }

      expect(finale.comeback_kid.name).to eq "bob"
    end
  end

  describe "#rewards_for" do
    it "lists what someone gets, settled or not, but not withdrawn pledges" do
      pending_reward = create(:challenge_reward, giver: anna, receiver: bob, challenge_story: story, description: "A coffee")
      fulfilled = create(:challenge_reward, giver: create(:challenge_participant, challenge_story: story), receiver: bob, challenge_story: story, status: :fulfilled)
      create(:challenge_reward, giver: bob, receiver: anna, challenge_story: story, status: :canceled)

      expect(finale.rewards_for(bob)).to contain_exactly(pending_reward, fulfilled)
      expect(finale.rewards_for(anna)).to be_empty
    end
  end

  describe "#flawless?" do
    it "is true only for someone who kept every day" do
      story.duration_in_days.times { check_in(anna, it) }
      check_in(bob, 0)

      expect(finale.flawless?(anna)).to be true
      expect(finale.flawless?(bob)).to be false
    end
  end
end
