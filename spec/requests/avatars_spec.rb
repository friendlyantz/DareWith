require "rails_helper"

RSpec.describe "Avatars", type: :request do
  let(:user) { create(:user) }

  before { sign_in_as(user) }

  describe "PATCH /avatar" do
    it "saves the photo" do
      patch avatar_path, params: {user: {avatar: fixture_file_upload("avatar.png", "image/png")}}

      expect(user.reload.avatar).to be_attached
      expect(flash[:notice]).to eq("Photo updated")
    end

    it "rejects files that aren't images" do
      patch avatar_path, params: {user: {avatar: fixture_file_upload("notes.txt", "text/plain")}}

      expect(user.reload.avatar).not_to be_attached
      expect(flash[:alert]).to eq("Photo must be an image")
    end
  end

  describe "DELETE /avatar" do
    it "removes the photo" do
      user.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")

      delete avatar_path

      expect(user.reload.avatar).not_to be_attached
    end
  end

  describe "showing the photo" do
    it "uses the photo instead of initials" do
      user.avatar.attach(io: file_fixture("avatar.png").open, filename: "avatar.png", content_type: "image/png")

      get profile_path

      expect(response.body).to include("res.cloudinary.com")
      expect(response.body).to include("Remove photo")
    end
  end
end
