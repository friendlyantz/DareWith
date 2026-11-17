require "rails_helper"

RSpec.describe "Old domains", type: :request do
  it "forwards to the current domain, keeping the path" do
    host! "strivo.me"

    get "/challenge_stories/42?invite=yes"

    expect(response).to have_http_status(:moved_permanently)
    expect(response).to redirect_to("https://#{Rails.configuration.app_host}/challenge_stories/42?invite=yes")
  end

  it "forwards every old domain the tunnel still serves" do
    %w[www.darewith.app app.strivo.me take-on.me].each do |old_host|
      host! old_host

      get "/today"

      expect(response).to redirect_to("https://#{Rails.configuration.app_host}/today")
    end
  end

  it "leaves the current domain alone" do
    get "/up"

    expect(response).to have_http_status(:ok)
  end
end
