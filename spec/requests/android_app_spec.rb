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

  describe "path configuration" do
    # The properties the app gives a page: every matching rule applies, later ones win
    def properties_for(path)
      response.parsed_body["rules"]
        .select { |rule| rule["patterns"].any? { Regexp.new(it).match?(path) } }
        .reduce({}) { |properties, rule| properties.merge(rule["properties"]) }
    end

    before { get android_path_configuration_path }

    it "is the same as the copy bundled in the app, which it uses until this one downloads" do
      bundled = JSON.parse(Rails.root.join("android/app/src/main/assets/json/path-configuration.json").read)

      expect(response.parsed_body).to eq(bundled)
    end

    it "starts a tab over when going back to its first page, instead of stacking it up" do
      %w[/ /today /today?day=2026-11-22 /challenge_check_ins /notifications /me].each do |tab|
        expect(properties_for(tab)).to include("presentation" => "replace_root"), tab
      end

      %w[/challenge_stories/1 /challenge_check_ins/1/challenge_check_in_replies /me/edit].each do |page|
        expect(properties_for(page)).not_to include("presentation"), page
      end
    end

    it "refreshes pages by pulling down, except forms" do
      expect(properties_for("/challenge_stories/1")).to include("pull_to_refresh_enabled" => true)

      %w[/challenge_stories/new /challenge_stories/1/edit /webauthn/session/new /email/session/code].each do |form|
        expect(properties_for(form)).to include("pull_to_refresh_enabled" => false), form
      end
    end

    it "slides up the forms for making or changing a challenge and pledging a reward" do
      id = "0b6c3f4e-1d2a-4c5b-9e8f-7a6b5c4d3e2f"

      ["/challenge_stories/new", "/challenge_stories/new?template=pushups", "/challenge_stories/#{id}/edit", "/challenge_stories/#{id}/challenge_rewards/new"].each do |form|
        expect(properties_for(form)).to include("context" => "modal"), form
      end

      ["/challenge_stories/#{id}", "/challenge_stories/#{id}/challenge_rewards", "/webauthn/session/new"].each do |page|
        expect(properties_for(page)).to include("context" => "default"), page
      end
    end
  end

  describe "the app's own toolbar and tabs" do
    it "replaces the site's header, tabs and back links once signed in, and gives the app the bell's count" do
      user = create(:user)
      create(:challenge_participant, user:)
      sign_in_as(user)

      get today_path, headers: {"User-Agent" => android_app}

      page = Capybara.string(response.body)
      expect(page).to have_css("meta[name='current-user-id'][content='#{user.id}']", visible: :all)
      expect(page).to have_css("meta[name='unread-notifications-count'][content='0']", visible: :all)
      expect(page).not_to have_css(".navbar")
      expect(page).not_to have_css("nav.dock")
    end

    it "keeps the site's tabs while signed out, since the app only has tabs once signed in" do
      get root_path, headers: {"User-Agent" => android_app}

      page = Capybara.string(response.body)
      expect(page).not_to have_css("meta[name='current-user-id']", visible: :all)
      expect(page).not_to have_css(".navbar")
      expect(page).to have_css("nav.dock")
    end

    it "keeps the site's header and tabs in browsers" do
      get root_path

      page = Capybara.string(response.body)
      expect(page).to have_css(".navbar")
      expect(page).to have_css("nav.dock")
    end

    it "leaves back links to the app's toolbar" do
      sign_in_as(create(:user))

      get credentials_path, headers: {"User-Agent" => android_app}
      expect(response.body).not_to include(%(href="#{profile_path}"))

      get credentials_path
      expect(response.body).to include(%(href="#{profile_path}"))
    end
  end

  it "doesn't offer browser notifications, which the app can't receive" do
    sign_in_as(create(:user))

    get profile_path, headers: {"User-Agent" => android_app}

    expect(response.body).not_to include("Notifications in this browser")
  end
end
