require "rails_helper"

RSpec.describe "Home", type: :request do
  describe "GET /" do
    context "when not signed in" do
      it "returns the home page" do
        get root_path

        expect(response).to have_http_status(:ok)
      end

      it "reloads open tabs when the JavaScript changes" do
        get root_path

        expect(response.body).to match(/<meta name="importmap-digest" content="\h{40}" data-turbo-track="reload">/)
      end

      it "dares Australian, NZ and British visitors to dare their mates" do
        %w[en-AU en-nz en-GB].each do |language|
          get root_path, headers: {"Accept-Language" => "#{language},en;q=0.9"}

          expect(response.body).to include("Dare Your Mates")
        end
      end

      it "dares everyone else to dare their friends" do
        ["en-US,en;q=0.9", "en", "de-DE", ""].each do |languages|
          get root_path, headers: {"Accept-Language" => languages}

          expect(response.body).to include("Dare Your Friends")
        end
      end
    end

    context "when signed in with active participation" do
      let(:user) { create(:user) }
      let(:story) { create(:challenge_story) }
      let!(:participant) { create(:challenge_participant, user: user, challenge_story: story) }

      before { sign_in_as(user) }

      it "redirects to Today" do
        get root_path

        expect(response).to redirect_to(today_path)
      end
    end

    context "when signed in without active participation" do
      let(:user) { create(:user) }

      before { sign_in_as(user) }

      it "redirects to Today" do
        get root_path

        expect(response).to redirect_to(today_path)
      end
    end
  end
end
