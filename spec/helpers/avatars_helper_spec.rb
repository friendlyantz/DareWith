require "rails_helper"

RSpec.describe AvatarsHelper, type: :helper do
  describe "#avatar_initials" do
    it "uses the first and last letter of a single-word name" do
      expect(helper.avatar_initials("maya")).to eq("MA")
      expect(helper.avatar_initials("mark")).to eq("MK")
    end

    it "uses the first letters of the first two parts" do
      expect(helper.avatar_initials("anton_k")).to eq("AK")
      expect(helper.avatar_initials("jo-anne-smith")).to eq("JA")
    end
  end

  describe "#avatar_tint" do
    it "gives the same name the same tint" do
      expect(helper.avatar_tint("maya")).to eq(helper.avatar_tint("maya"))
    end
  end
end
