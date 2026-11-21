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

    it "looks the same for an email with no account, so attackers can't enumerate users" do
      post email_session_path, params: {session: {email: "unknown@example.com"}}

      expect(response).to have_http_status(:success)
      expect(response.body).to include("Check your email for a 6-digit code and a link.")
      expect(response.body).to include("Code from the email")
    end

    it "emails a code to join, but creates no account until a username is picked" do
      expect {
        perform_enqueued_jobs { post email_session_path, params: {session: {email: "new@example.com"}} }
      }.not_to change(User, :count)

      expect(ActionMailer::Base.deliveries.last).to have_attributes(to: ["new@example.com"], subject: /\A\d{6} is your code to join DareWith\z/)
    end

    it "asks for a real email address" do
      post email_session_path, params: {session: {email: "not-an-email"}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(enqueued_jobs).to be_empty
    end

    it "limits how many emails are sent, the same way with or without an account" do
      allow(Email::SessionsController.cache_store).to receive(:increment).and_return(4)

      [user.email, "unknown@example.com"].each do |email|
        post email_session_path, params: {session: {email:}}

        expect(response).to have_http_status(:too_many_requests)
        expect(response.body).to include("That&#39;s a lot of emails")
      end
      expect(enqueued_jobs).to be_empty
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

      expect(response).to redirect_to(new_challenge_story_path)
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

      expect(response).to redirect_to(new_challenge_story_path)
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

  describe "signing up with an email that has no account" do
    def request_signup_code(email = "new@example.com")
      perform_enqueued_jobs { post email_session_path, params: {session: {email:}} }
      ActionMailer::Base.deliveries.last.subject[/\d{6}/]
    end

    # Just the path, so it opens on the same host, like the real link does in the same browser
    def signup_link
      URI(ActionMailer::Base.deliveries.last.text_part.body.to_s[%r{http://\S+/email/registration/verify\S+}]).request_uri
    end

    it "takes the code, then a username, and signs them in to make their first challenge" do
      code = request_signup_code(" New@Example.com ")

      post confirm_email_session_path, params: {code:}
      expect(response).to redirect_to(new_email_registration_path)
      follow_redirect!
      expect(response.body).to include("Pick a username", "new@example.com")

      expect {
        post email_registration_path, params: {user: {username: " newbie "}}
      }.to change(User, :count).by(1)

      new_user = User.find_by(username: "newbie")
      expect(new_user).to have_attributes(email: "new@example.com", email_verified?: true)
      expect(session[:user_id]).to eq(new_user.id)
      expect(response).to redirect_to(new_challenge_story_path)
    end

    it "takes the link instead, and keeps the invite" do
      story = create(:challenge_story)
      get challenge_story_path(story)
      request_signup_code

      get signup_link
      expect(response).to redirect_to(new_email_registration_path)
      post email_registration_path, params: {user: {username: "newbie"}}

      expect(response).to redirect_to(challenge_story_path(story))
    end

    it "won't make an account from a link forwarded to someone else" do
      request_signup_code("sender@example.com")

      someone_else = open_session
      someone_else.get signup_link
      expect(someone_else.response).to have_http_status(:forbidden)
      expect(someone_else.response.body).to include("This link opened in a different browser", "Email a new code to use here")

      someone_else.get new_email_registration_path
      expect(someone_else.response.location).to end_with(new_email_session_path)
    end

    it "can carry on in the browser the link opened in, with a new code emailed there" do
      request_signup_code
      link = signup_link
      mail_app_browser = open_session
      mail_app_browser.get link

      perform_enqueued_jobs { mail_app_browser.post email_session_path, params: {session: {email: "new@example.com"}} }
      mail_app_browser.post confirm_email_session_path, params: {code: ActionMailer::Base.deliveries.last.subject[/\d{6}/]}

      expect(mail_app_browser.response.location).to end_with(new_email_registration_path)
    end

    it "still takes the link after the code was typed" do
      post confirm_email_session_path, params: {code: request_signup_code}

      get signup_link

      expect(response).to redirect_to(new_email_registration_path)
    end

    it "lets a link preview open the link without using it up" do
      request_signup_code
      link = signup_link

      open_session.get link
      get link

      expect(response).to redirect_to(new_email_registration_path)
    end

    it "won't use the link again once the account exists" do
      request_signup_code
      link = signup_link
      get link
      post email_registration_path, params: {user: {username: "newbie"}}

      open_session.tap { it.get link }.then do |other_browser|
        expect(other_browser.response.location).to end_with(new_email_session_path)
        expect(other_browser.flash[:alert]).to include("expired or was already used")
      end
    end

    it "refuses a tampered link" do
      get verify_email_registration_path, params: {token: "forged"}

      expect(response).to redirect_to(new_email_session_path)
    end

    it "locks the code after five wrong tries" do
      code = request_signup_code
      wrong = (code == "000000") ? "111111" : "000000"

      5.times { post confirm_email_session_path, params: {code: wrong} }
      post confirm_email_session_path, params: {code:}

      expect(response).to have_http_status(:unprocessable_content)
      expect(session[:verified_email_signup_id]).to be_nil
    end

    it "expires the code after 15 minutes" do
      code = request_signup_code

      travel_to(16.minutes.from_now) { post confirm_email_session_path, params: {code:} }

      expect(response).to have_http_status(:unprocessable_content)
    end

    it "only asks for a username once the email is proven" do
      request_signup_code

      get new_email_registration_path
      expect(response).to redirect_to(new_email_session_path)

      expect { post email_registration_path, params: {user: {username: "newbie"}} }.not_to change(User, :count)
    end

    it "keeps them on the username step when the username is taken" do
      create(:user, username: "newbie")
      post confirm_email_session_path, params: {code: request_signup_code}

      post email_registration_path, params: {user: {username: "newbie"}}

      expect(response).to have_http_status(:unprocessable_content)
      expect(response.body).to include("Username has already been taken")
    end

    it "sends someone with an account their sign-in code instead" do
      perform_enqueued_jobs { post email_session_path, params: {session: {email: user.email}} }

      expect(ActionMailer::Base.deliveries.last.subject).to match(/is your DareWith sign-in code/)
      expect(EmailSignup.count).to eq(0)
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
