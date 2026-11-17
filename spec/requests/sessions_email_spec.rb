# frozen_string_literal: true

require "rails_helper"

RSpec.describe "Sessions Email Authentication", type: :request do
  let(:user) { create(:user, email: "test@example.com") }

  describe "GET /email/session/new" do
    it "returns email sign-in form" do
      get new_email_session_path

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Continue with email")
      expect(response.body).to include("email")
    end
  end

  describe "POST /email/session" do
    it "sends magic link email to registered user" do
      expect {
        post email_session_path, params: {session: {email: user.email}}
      }.to have_enqueued_job

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Check your email")
    end

    it "returns success for unregistered email so attackers can't enumerate users" do
      post email_session_path, params: {session: {email: "unknown@example.com"}}

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Check your email for a 6-digit code and a sign-in link.")
    end

    it "doesn't create an account for a mistyped email" do
      expect {
        post email_session_path, params: {session: {email: "tset@example.com", username: "someone"}}
      }.not_to change(User, :count)

      expect(enqueued_jobs).to be_empty
    end

    it "enforces rate limit (3 emails per 15 minutes)" do
      user.update!(last_email_sent_at: 5.minutes.ago)

      post email_session_path, params: {session: {email: user.email}}

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("recently sent")
    end

    it "strips and lowercases email" do
      create(:user, email: "test@example.com")
      post email_session_path, params: {session: {email: "  TEST@EXAMPLE.COM  "}}

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Check your email")
    end

    it "generates and stores hashed token" do
      post email_session_path, params: {session: {email: user.email}}

      user.reload
      expect(user.email_login_token).to be_present
      expect(user.email_login_token_expires_at).to be_present
    end

    it "sets token expiry to 24 hours from now" do
      post email_session_path, params: {session: {email: user.email}}

      user.reload
      expect(user.email_login_token_expires_at).to be_within(5.seconds).of(24.hours.from_now)
    end
  end

  describe "GET /email/session/verify" do
    it "only shows a Sign in button, so link previews don't use up the token" do
      token = user.generate_email_login_token!

      get verify_email_session_path, params: {token:, return_to: "/today"}

      expect(response).to have_http_status(:ok)
      expect(response.body).to include("Sign in as #{user.username}")
      expect(session[:user_id]).to be_nil
      expect(user.reload.email_login_token).to be_present
    end
  end

  describe "POST /email/session/verify" do
    it "signs in user with valid token" do
      token = user.generate_email_login_token!

      post verify_email_session_path, params: {token: token}

      expect(response).to redirect_to(root_path)
      expect(session[:user_id]).to eq(user.id)
    end

    it "returns to the challenge the visitor was invited to" do
      story = create(:challenge_story)
      get challenge_story_path(story)
      token = user.generate_email_login_token!

      post verify_email_session_path, params: {token: token}

      expect(response).to redirect_to(challenge_story_path(story))
    end

    it "returns to the page that asked them to sign in" do
      get today_path
      token = user.generate_email_login_token!

      post verify_email_session_path, params: {token: token}

      expect(response).to redirect_to(today_path)
    end

    it "only returns once" do
      get challenge_story_path(create(:challenge_story))
      post verify_email_session_path, params: {token: user.generate_email_login_token!}
      delete webauthn_session_path

      post verify_email_session_path, params: {token: user.generate_email_login_token!}

      expect(response).to redirect_to(root_path)
    end

    it "clears token after successful verification" do
      token = user.generate_email_login_token!

      post verify_email_session_path, params: {token: token}

      user.reload
      expect(user.email_login_token).to be_nil
      expect(user.email_login_token_expires_at).to be_nil
    end

    it "marks email as verified after sign-in" do
      token = user.generate_email_login_token!

      expect(user.email_verified?).to be false

      post verify_email_session_path, params: {token: token}

      user.reload
      expect(user.email_verified?).to be true
    end
  end

  describe "a bad link" do
    it "returns error for invalid token" do
      get verify_email_session_path, params: {token: "invalid-token"}

      expect(response).to redirect_to(new_webauthn_session_path)
      expect(flash[:alert]).to include("Invalid or expired")
      expect(session[:user_id]).to be_nil
    end

    it "returns error for expired token" do
      token = user.generate_email_login_token!
      user.update!(email_login_token_expires_at: 1.hour.ago)

      get verify_email_session_path, params: {token: token}

      expect(response).to redirect_to(new_webauthn_session_path)
      expect(flash[:alert]).to include("expired")
      expect(session[:user_id]).to be_nil
    end

    it "returns error when no token provided" do
      get verify_email_session_path, params: {token: ""}

      expect(response).to redirect_to(new_webauthn_session_path)
      expect(flash[:alert]).to include("Invalid sign-in link")
      expect(session[:user_id]).to be_nil
    end
  end

  describe "typing the code from the email" do
    def request_code
      perform_enqueued_jobs { post email_session_path, params: {session: {email: user.email}} }
      ActionMailer::Base.deliveries.last.subject[/\d{6}/]
    end

    it "signs in and returns to the invite without leaving this browser" do
      story = create(:challenge_story)
      get challenge_story_path(story)
      code = request_code

      post confirm_email_session_path, params: {code: "#{code[0, 3]} #{code[3, 3]}"}

      expect(response).to redirect_to(challenge_story_path(story))
      expect(session[:user_id]).to eq(user.id)
      expect(user.reload.email_login_code_digest).to be_nil
    end

    it "locks the code after five wrong tries" do
      code = request_code
      wrong = (code == "000000") ? "111111" : "000000"

      5.times { post confirm_email_session_path, params: {code: wrong} }
      post confirm_email_session_path, params: {code:}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("That code didn&#39;t work")
      expect(session[:user_id]).to be_nil
    end

    it "expires after 15 minutes" do
      code = request_code

      travel_to(16.minutes.from_now) { post confirm_email_session_path, params: {code:} }

      expect(session[:user_id]).to be_nil
    end

    it "only works in the browser that asked for it" do
      code = request_code
      other_browser = open_session

      other_browser.post confirm_email_session_path, params: {code:}

      expect(other_browser.response.location).to end_with(new_email_session_path)
      expect(other_browser.session[:user_id]).to be_nil
    end

    it "keeps the code box when an email was just sent" do
      request_code
      post email_session_path, params: {session: {email: user.email}}

      expect(response).to have_http_status(:too_many_requests)
      expect(response.body).to include("Code from the email")
    end
  end

  it "the link carries the invite, so it works when it opens in another browser" do
    story = create(:challenge_story)
    get challenge_story_path(story)
    perform_enqueued_jobs { post email_session_path, params: {session: {email: user.email}} }
    link = ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{http://\S+/verify\S+}]

    mail_app_browser = open_session
    mail_app_browser.get link
    expect(mail_app_browser.response.body).to include(%(name="return_to" value="#{challenge_story_path(story)}"))
    mail_app_browser.post link

    expect(mail_app_browser.response.location).to end_with(challenge_story_path(story))
  end

  describe "POST /email/registration" do
    it "creates the account and emails a code" do
      expect {
        post email_registration_path, params: {session: {email: " New@Example.com ", username: "newbie"}}
      }.to change(User, :count).by(1).and have_enqueued_job

      expect(User.last).to have_attributes(email: "new@example.com", username: "newbie")
      expect(response.body).to include("Code from the email")
    end

    it "signs in with the code like any other email sign-in" do
      perform_enqueued_jobs { post email_registration_path, params: {session: {email: "new@example.com", username: "newbie"}} }
      code = ActionMailer::Base.deliveries.last.subject[/\d{6}/]

      post confirm_email_session_path, params: {code:}

      expect(session[:user_id]).to eq(User.find_by(username: "newbie").id)
    end

    it "emails the owner of a taken email instead of saying it's taken" do
      expect {
        post email_registration_path, params: {session: {email: user.email, username: "newbie"}}
      }.to have_enqueued_job

      expect(User.where(username: "newbie")).to be_empty
      expect(response.body).to include("Check your email for a 6-digit code and a sign-in link.")
    end

    it "asks for an email and a username" do
      expect {
        post email_registration_path, params: {session: {email: "", username: "newbie"}}
        post email_registration_path, params: {session: {email: "new@example.com", username: ""}}
      }.not_to change(User, :count)

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Username can&#39;t be blank")
    end
  end

  describe "Email mailer integration" do
    it "sends magic link email with correct parameters" do
      mail = double
      expect(UserMailer).to receive(:magic_link_email).and_return(mail)
      expect(mail).to receive(:deliver_later)

      post email_session_path, params: {session: {email: user.email}}
    end
  end
end
