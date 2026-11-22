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

  describe "signing up" do
    # Picks a username, then answers with the fake authenticator's new passkey
    def sign_up_with_passkey
      post webauthn_registration_path, params: {registration: {username: "newbie"}}, as: :json
      created = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
      post callback_webauthn_registration_path, params: created, as: :json
    end

    it "starts them on making their first challenge" do
      sign_up_with_passkey

      expect(response.parsed_body["redirect_to"]).to eq new_challenge_story_path
    end

    it "doesn't take them back to a demo challenge they looked at first" do
      demo = create(:challenge_story, id: "#{ChallengeStory::DEMO_ID_PREFIX}000000000001")
      get challenge_story_path(demo)

      sign_up_with_passkey

      expect(response.parsed_body["redirect_to"]).to eq new_challenge_story_path
    end

    it "takes them back to the challenge they were invited to" do
      story = create(:challenge_story)
      get challenge_story_path(story)

      sign_up_with_passkey

      expect(response.parsed_body["redirect_to"]).to eq challenge_story_path(story)
    end
  end

  describe "signing in" do
    let(:user_handle) { Base64.urlsafe_decode64(user.webauthn_id) }

    # Starts sign-in, then answers with the fake authenticator's passkey
    def sign_in_with_passkey(**assertion_options)
      post webauthn_session_path, as: :json
      assertion = client.get(challenge: response.parsed_body["challenge"], user_verified: true, **assertion_options)
      post callback_webauthn_session_path, params: assertion, as: :json
    end

    it "finds the account from the passkey" do
      register_passkey

      sign_in_with_passkey(user_handle:)

      expect(response.parsed_body["status"]).to eq "ok"
      expect(session[:user_id]).to eq user.id
    end

    # Not the home page: the Android app would go back to the signed-out home page it came from
    it "goes straight to Today for someone already in a challenge" do
      register_passkey
      create(:challenge_participant, user:)

      sign_in_with_passkey(user_handle:)

      expect(response.parsed_body["redirect_to"]).to eq today_path
    end

    it "lets the browser offer every passkey it holds" do
      register_passkey

      post webauthn_session_path, as: :json

      expect(response.parsed_body["allowCredentials"]).to eq []
    end

    it "refuses a passkey that says it was made for someone else" do
      register_passkey

      sign_in_with_passkey(user_handle: Base64.urlsafe_decode64(create(:user).webauthn_id))

      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:user_id]).to be_nil
    end

    it "records whether the passkey syncs" do
      credential = register_passkey

      sign_in_with_passkey(user_handle:, backup_eligibility: true, backup_state: true)

      expect(response.parsed_body["status"]).to eq "ok"
      expect(credential.reload.backed_up).to be true
    end
  end

  describe "adding a passkey" do
    before { sign_in_as(user) }

    it "asks for a passkey that remembers the account, so sign-in needs no username" do
      post credentials_path, as: :json

      expect(response.parsed_body.dig("authenticatorSelection", "residentKey")).to eq "required"
    end

    it "records a passkey that can't sync" do
      post credentials_path, as: :json
      created = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
      post callback_credentials_path, params: created, as: :json

      expect(response.parsed_body["status"]).to eq "ok"
      expect(user.credentials.last.backed_up).to be false
    end

    it "names the passkey after the browser it was made in when the password manager is unknown" do
      post credentials_path, as: :json
      created = client.create(challenge: response.parsed_body["challenge"], user_verified: true)
      post callback_credentials_path, params: created, as: :json,
        headers: {"User-Agent" => "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0.0.0 Safari/537.36"}

      expect(user.credentials.last.nickname).to eq "Chrome on Mac"
    end
  end

  describe "after moving to a new domain" do
    let!(:old_passkey) { create(:credential, user:, rp_id: "strivo.me", nickname: "Old iPhone") }

    it "hides passkeys made on the old domain" do
      sign_in_as(user)

      get credentials_path

      expect(response.body).not_to include("Old iPhone")
      expect(response.body).to include("We moved to #{Rails.configuration.app_host}")
    end

    it "sends them to add a new passkey once they sign in by email" do
      post verify_email_session_path, params: {token: user.generate_email_login_token!}

      expect(response).to redirect_to(credentials_path)
    end

    it "stops once they have a passkey here" do
      create(:credential, user:)

      expect(user.passkeys_left_on_old_domain?).to be false
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

    it "suggests a first passkey to email-only users in a real browser" do
      get profile_path
      expect(response.body).to include("Sign in faster next time")

      get profile_path, headers: {"User-Agent" => "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 350.0"}
      expect(response.body).not_to include("Sign in faster next time")
    end

    it "shows when each passkey was added, oldest first" do
      create(:credential, user:, nickname: "New laptop", created_at: Time.zone.local(2026, 11, 18))
      create(:credential, user:, nickname: "Old phone", created_at: Time.zone.local(2025, 3, 4))

      get credentials_path

      expect(response.body).to include("Added 4 Mar 2025", "Added 18 Nov 2026")
      expect(response.body.index("Old phone")).to be < response.body.index("New laptop")
    end

    it "labels each passkey" do
      create(:credential, user:, nickname: "iPhone", backed_up: true)
      create(:credential, user:, nickname: "YubiKey", backed_up: false)

      get credentials_path

      expect(response.body).to include("Synced", "Not synced")
    end
  end
end
