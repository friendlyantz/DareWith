require "rails_helper"

RSpec.describe "In-app browsers", type: :request do
  let(:android_webview) { "Mozilla/5.0 (Linux; Android 14; Pixel 9; wv) AppleWebKit/537.36 (KHTML, like Gecko) Version/4.0 Chrome/131.0 Mobile Safari/537.36 Telegram-Android/11.5" }
  let(:ios_in_app) { "Mozilla/5.0 (iPhone; CPU iPhone OS 18_1 like Mac OS X) AppleWebKit/605.1.15 (KHTML, like Gecko) Mobile/15E148 Instagram 350.0" }
  let(:android_chrome) { "Mozilla/5.0 (Linux; Android 14; Pixel 9) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/131.0 Mobile Safari/537.36" }
  let(:story) { create(:challenge_story) }

  it "guides invited visitors in an Android in-app browser to their real browser" do
    get challenge_story_path(story), headers: {"User-Agent" => android_webview}

    expect(response.body).to include("Open this in your browser")
    expect(response.body).to include(%(data-clipboard-text-value="#{challenge_story_url(story)}"))
  end

  it "guides visitors in an iOS in-app browser too" do
    get challenge_story_path(story), headers: {"User-Agent" => ios_in_app}

    expect(response.body).to include("Open this in your browser")
  end

  it "offers one tap to reopen the invite in the default browser on Android" do
    get challenge_story_path(story), headers: {"User-Agent" => android_webview}

    expect(response.body).to include("Open in your browser")
    expect(response.body).to include("intent://www.example.com/challenge_stories/#{story.id}#Intent;scheme=http;action=android.intent.action.VIEW;")
    expect(response.body).not_to include("package=com.android.chrome")
  end

  it "offers one tap to reopen the invite in Safari on iPhone" do
    get challenge_story_path(story), headers: {"User-Agent" => ios_in_app}

    expect(response.body).to include(%(href="x-safari-#{challenge_story_url(story)}">Open in Safari</a>))
  end

  it "leaves regular browsers alone" do
    get challenge_story_path(story), headers: {"User-Agent" => android_chrome}

    expect(response.body).not_to include("Open this in your browser")
    expect(response.body).to include("Sign up to join")
  end

  it "copies the invite link, not the sign-in page, on the sign-up page" do
    get challenge_story_path(story), headers: {"User-Agent" => android_webview}
    get new_webauthn_registration_path, headers: {"User-Agent" => android_webview}

    expect(response.body).to include(%(data-clipboard-text-value="#{challenge_story_url(story)}"))
  end

  it "sends a sign-in link opened in Instagram to Safari without using it up" do
    user = create(:user)
    token = user.generate_email_login_token!

    get verify_email_session_path(token:), headers: {"User-Agent" => ios_in_app}

    expect(response.body).to include("Open in Safari")
    expect(response.body).to include("x-safari-http://www.example.com/email/session/verify?token=#{token}")
    expect(response.body).to include("Sign in here anyway")
    expect(session[:user_id]).to be_nil
    expect(user.reload.verify_email_login_token(token)).to be true
  end
end
