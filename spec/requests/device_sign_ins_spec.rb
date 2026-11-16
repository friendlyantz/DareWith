require "rails_helper"

RSpec.describe "Device sign-ins", type: :request do
  let(:user) { create(:user) }

  # The signed-in phone that approves the new device
  let(:phone) do
    open_session.tap { it.get test_sign_in_path(user_id: user.id) }
  end

  def start_on_new_device
    post device_sign_in_path, headers: {"User-Agent" => build(:device_sign_in).user_agent}
    DeviceSignIn.last
  end

  it "signs in the new device once the phone approves its code" do
    device_sign_in = start_on_new_device
    follow_redirect!
    expect(response.body).to include(%(aria-label="QR code"))

    phone.get new_device_sign_in_approval_path(code: device_sign_in.code.downcase)
    expect(phone.response.body).to include("Sign in Chrome on Mac?")

    expect { phone.post device_sign_in_approval_path, params: {code: device_sign_in.code} }
      .to have_broadcasted_to(device_sign_in.to_gid_param)
    expect(phone.response.location).to end_with profile_path

    get device_sign_in_path
    expect(response).to redirect_to(credentials_path)
    follow_redirect!
    expect(response.body).to include(user.username)
  end

  it "returns an invited visitor to the challenge" do
    story = create(:challenge_story)
    get challenge_story_path(story)
    device_sign_in = start_on_new_device
    device_sign_in.approve!(user)

    get device_sign_in_path

    expect(response).to redirect_to(challenge_story_path(story))
  end

  it "keeps waiting until approved" do
    start_on_new_device

    get device_sign_in_path

    expect(response).to have_http_status(:ok)
    expect(response.body).to include("Waiting for approval")
  end

  it "doesn't sign in a browser that didn't ask" do
    device_sign_in = create(:device_sign_in)
    phone.post device_sign_in_approval_path, params: {code: device_sign_in.code}

    get device_sign_in_path

    expect(response).to redirect_to(new_webauthn_session_path)
    expect(device_sign_in.reload).to be_approved
  end

  it "offers a new code once it expires" do
    device_sign_in = start_on_new_device
    device_sign_in.update!(expires_at: 1.minute.ago)

    get device_sign_in_path

    expect(response.body).to include("This code has expired")
  end

  describe "approving" do
    it "asks visitors to sign in first" do
      get new_device_sign_in_approval_path(code: "ABC234")

      expect(response).to redirect_to(new_webauthn_session_path)
    end

    it "rejects an unknown or expired code" do
      device_sign_in = create(:device_sign_in, expires_at: 1.minute.ago)

      phone.post device_sign_in_approval_path, params: {code: device_sign_in.code}

      expect(phone.response.location).to end_with new_device_sign_in_approval_path
      expect(device_sign_in.reload).to be_pending
    end

    it "shows an error for a code that doesn't match" do
      phone.get new_device_sign_in_approval_path(code: "ZZZZZZ")

      expect(phone.response.body).to include("That code has expired or doesn't exist.")
    end
  end
end
