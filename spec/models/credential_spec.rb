require "rails_helper"

RSpec.describe Credential do
  describe ".nickname_for" do
    let(:iphone_safari) { "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/18.1 Mobile/15E148 Safari/604.1" }

    it "names a passkey after the password manager that made it" do
      expect(described_class.nickname_for("fbfc3007-154e-4ecc-8c0b-6e020557d7bd", iphone_safari)).to eq "Apple Passwords"
    end

    it "names a security key after its model" do
      expect(described_class.nickname_for("cb69481e-8ff7-4039-93ec-0a2729a154a8", iphone_safari)).to eq "YubiKey 5 Series"
    end

    it "falls back to the browser when the password manager doesn't say who it is" do
      expect(described_class.nickname_for(nil, iphone_safari)).to eq "Safari on iPhone"
    end

    it "is just a passkey when neither is known" do
      expect(described_class.nickname_for(nil, nil)).to eq "Passkey"
    end
  end
end
