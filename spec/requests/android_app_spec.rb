require "rails_helper"

RSpec.describe "The Android app", type: :request do
  let(:android_app) { "Hotwire Native Android; Turbo Native Android; bridge-components: []; Mozilla/5.0 (Linux; Android 16; Pixel 9; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/142.0 Mobile Safari/537.36" }

  it "is linked to this site, so it can use the site's passkeys" do
    get "/.well-known/assetlinks.json", headers: {"User-Agent" => "Google-Digital-Asset-Links"}

    expect(response).to have_http_status(:ok)
    expect(response.parsed_body.sole).to include(
      "relation" => include("delegate_permission/common.get_login_creds"),
      "target" => {
        "namespace" => "android_app",
        "package_name" => "app.darewith",
        "sha256_cert_fingerprints" => include("A5:F1:3A:BA:34:02:02:98:BD:8E:3E:16:C1:85:78:3F:5D:16:25:3C:4B:05:CA:84:89:5C:DB:D6:72:32:BD:CC")
      }
    )
  end

  it "accepts passkeys from the app, which come from its signing key instead of the web page" do
    expect(WebAuthn.configuration.allowed_origins).to include("android:apk-key-hash:pfE6ujQCApi9jj4WwYV4P10WJTxLBcqEiVzb1nIyvcw")
  end

  it "offers passkeys instead of sending people to another browser" do
    get new_webauthn_registration_path, headers: {"User-Agent" => android_app}

    expect(response.body).not_to include("Open this in your browser")
  end
end
