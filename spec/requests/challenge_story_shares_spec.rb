require "rails_helper"

RSpec.describe "ChallengeStoryShares", type: :request do
  let(:story) { create(:challenge_story, title: "50 push-ups", description: "Stronger by summer") }

  describe "GET /c/:share_code" do
    it "redirects the short link to the challenge" do
      get challenge_story_share_path(story.share_code)

      expect(response).to redirect_to(challenge_story_path(story))
    end

    it "is not found for an unknown code" do
      get challenge_story_share_path("nope1234")

      expect(response).to have_http_status(:not_found)
    end
  end

  describe "the link preview" do
    it "gives link previews the title, goal and who's in" do
      create(:challenge_participant, challenge_story: story)

      get challenge_story_path(story), headers: {"User-Agent" => "WhatsApp/2.24.1 A"}

      expect(response).to have_http_status(:ok)
      page = Nokogiri::HTML(response.body)
      expect(page.at('meta[property="og:title"]')["content"]).to eq("50 push-ups")
      expect(page.at('meta[property="og:description"]')["content"]).to include("Check in every day", "1 of 4 in", "Stronger by summer")
      expect(page.at('meta[property="og:url"]')["content"]).to end_with("/c/#{story.share_code}")
      expect(page.at('meta[property="og:image"]')["content"]).to start_with("http")
    end
  end
end
