require "rails_helper"

RSpec.describe ShareCardsHelper, type: :helper do
  describe "#share_card_values" do
    let(:challenge_story) { create(:challenge_story, title: "Push-ups", start: Time.zone.today - 9.days, finish: Time.zone.today + 20.days) }
    let(:participant) { create(:challenge_participant, challenge_story:) }

    def check_in(days_ago, amount: nil)
      create(:challenge_check_in, challenge_participant: participant, checked_in_on: Time.zone.today - days_ago, amount:)
    end

    it "shows a running streak and how far into the challenge it is" do
      [2, 1, 0].each { check_in(it) }

      values = helper.share_card_values(participant)

      expect(values).to include(title: "Push-ups", headline: "🔥 3", caption: "days in a row", progress_label: "Day 10 of 30")
      expect(values[:progress]).to eq 0.333
      expect(values[:url]).to end_with "/challenge_stories/#{challenge_story.id}"
      expect(values[:photo_url]).to be_nil
    end

    it "shows the total toward a target by the end, with the bar toward the target" do
      challenge_story.update!(unit: :km, target_amount: 100, target_scope: :total)
      check_in(1, amount: 20)
      check_in(0, amount: 5.5)

      values = helper.share_card_values(participant)

      expect(values).to include(headline: "25.5 / 100 km", caption: "toward the target", progress: 0.255)
    end

    it "shows the amount so far without a streak" do
      challenge_story.update!(unit: :reps)
      check_in(3, amount: 40)

      expect(helper.share_card_values(participant)).to include(headline: "40 reps", caption: "so far")
    end

    it "shows days kept for a plain challenge without a streak" do
      check_in(5)
      check_in(3)

      expect(helper.share_card_values(participant)).to include(headline: "2", caption: "days kept")
    end

    it "uses the latest photo" do
      create(:challenge_check_in, :with_photo, challenge_participant: participant, checked_in_on: Time.zone.today)

      expect(helper.share_card_values(participant)[:photo_url]).to start_with "https://res.cloudinary.com/"
    end
  end
end
