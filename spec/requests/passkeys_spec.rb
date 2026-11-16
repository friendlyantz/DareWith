require "rails_helper"
require "webauthn/fake_client"

RSpec.describe "Passkeys", type: :request do
  let(:client) { WebAuthn::FakeClient.new(Rails.configuration.webauthn_origin) }
  let(:user) { create(:user) }

  # Registers a real passkey for the user with the fake authenticator
  def register_passkey
    created = client.create(user_verified: true)
    webauthn_credential = WebAuthn::Credential.from_create(created)
    create(:credential, user:,
      external_id: Base64.urlsafe_encode64(webauthn_credential.raw_id, padding: false),
      public_key: webauthn_credential.public_key)
  end

  describe "signing in" do
    it "records whether the passkey syncs" do
      credential = register_passkey

      post webauthn_session_path, params: {session: {username: user.username}}, as: :json
      assertion = client.get(challenge: response.parsed_body["challenge"], user_verified: true, backup_eligibility: true, backup_state: true)
      post callback_webauthn_session_path, params: assertion, as: :json

      expect(response.parsed_body["status"]).to eq "ok"
      expect(credential.reload.backed_up).to be true
    end
  end

  describe "adding a passkey" do
    before { sign_in_as(user) }

    it "records a passkey that can't sync" do
      post credentials_path, as: :json
      created = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
      post callback_credentials_path, params: created.merge(credential_nickname: "Work laptop"), as: :json

      expect(response.parsed_body["status"]).to eq "ok"
      expect(user.credentials.find_by!(nickname: "Work laptop").backed_up).to be false
    end
  end

  describe "the backup nudge" do
    before { sign_in_as(user) }

    it "shows when the only passkey can't sync" do
      create(:credential, user:, backed_up: false)

      get profile_path

      expect(response.body).to include("Your passkey only lives on one device")
    end

    [
      ["a synced passkey", [true]],
      ["a passkey not seen since this change", [nil]],
      ["two passkeys that can't sync", [false, false]]
    ].each do |situation, flags|
      it "stays hidden with #{situation}" do
        flags.each { create(:credential, user:, backed_up: it) }

        get profile_path

        expect(response.body).not_to include("Your passkey only lives on one device")
      end
    end

    it "labels each passkey" do
      create(:credential, user:, nickname: "iPhone", backed_up: true)
      create(:credential, user:, nickname: "YubiKey", backed_up: false)

      get credentials_path

      expect(response.body).to include("Synced", "Not synced")
    end
  end
end
