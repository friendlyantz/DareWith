require "rails_helper"

RSpec.describe ChallengeStory::Template do
  describe "#build" do
    ChallengeStory::Template::CATALOGUE.each_key do |key|
      it "makes a valid challenge from #{key}" do
        expect(described_class.find(key).build).to be_valid
      end
    end

    it "starts today and runs the template's length" do
      challenge_story = described_class.find(:push_ups).build

      expect(challenge_story.start).to eq Time.zone.today
      expect(challenge_story.duration_in_days).to eq 30
    end

    it "copies the goal" do
      challenge_story = described_class.find(:run).build

      expect(challenge_story.goal.summary).to eq "3× a week · 5 km each time"
    end
  end

  describe ".find" do
    it "finds a template by its key as a string" do
      expect(described_class.find("read").title).to eq "Read 20 pages a day"
    end

    it "returns nil for an unknown or missing key" do
      expect(described_class.find("nope")).to be_nil
      expect(described_class.find(nil)).to be_nil
    end
  end
end
