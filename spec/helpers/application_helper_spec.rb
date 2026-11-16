require "rails_helper"

RSpec.describe ApplicationHelper, type: :helper do
  describe "#short_time_ago" do
    it "formats recent times compactly" do
      expect(helper.short_time_ago(10.seconds.ago)).to eq("just now")
      expect(helper.short_time_ago(5.minutes.ago)).to eq("5m ago")
      expect(helper.short_time_ago(3.hours.ago)).to eq("3h ago")
      expect(helper.short_time_ago(2.days.ago)).to eq("2d ago")
    end
  end
end
