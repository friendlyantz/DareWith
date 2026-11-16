require "rails_helper"

RSpec.describe DeviceSignIn do
  it "gets a short code that expires" do
    device_sign_in = create(:device_sign_in)

    expect(device_sign_in.code).to match(/\A[A-HJ-NP-Z2-9]{6}\z/)
    expect(device_sign_in.expires_at).to be_within(1.second).of(5.minutes.from_now)
  end

  describe ".find_pending" do
    let!(:device_sign_in) { create(:device_sign_in, code: "ABC234") }

    it "finds the code however it's typed" do
      expect(DeviceSignIn.find_pending(" abc 234 ")).to eq device_sign_in
    end

    it "ignores expired and approved codes" do
      device_sign_in.update!(expires_at: 1.minute.ago)
      expect(DeviceSignIn.find_pending("ABC234")).to be_nil

      device_sign_in.update!(expires_at: 1.minute.from_now, user: create(:user), state: :approved)
      expect(DeviceSignIn.find_pending("ABC234")).to be_nil
    end
  end

  it "counts codes expired over a day ago as stale" do
    create(:device_sign_in, expires_at: 1.hour.ago)
    stale = create(:device_sign_in, expires_at: 2.days.ago)

    expect(DeviceSignIn.stale).to contain_exactly(stale)
  end

  describe "#claim!" do
    it "returns the approving user only once" do
      device_sign_in = create(:device_sign_in, :approved)

      expect(device_sign_in.claim!).to eq device_sign_in.user
      expect(DeviceSignIn.find(device_sign_in.id).claim!).to be_nil
      expect(device_sign_in.reload).to be_used
    end

    it "returns nothing until approved or after expiry" do
      expect(create(:device_sign_in).claim!).to be_nil
      expect(create(:device_sign_in, :approved, expires_at: 1.minute.ago).claim!).to be_nil
    end
  end

  it "describes the device from its browser" do
    expect(build(:device_sign_in).device_label).to eq "Chrome on Mac"
    expect(build(:device_sign_in, user_agent: nil).device_label).to eq "a new device"
  end
end
