require "system_helper"

RSpec.describe "Home Page", type: :system do
  let(:home_page) { prism.library.home }

  scenario "visitor sees the landing page" do
    home_page.load

    expect(page).to have_content(/Dare Your (Mates|Friends)/)
    expect(page).to have_content("DareWith")
  end

  scenario "visitor can navigate to sign in" do
    home_page.load

    expect(home_page.dock).to have_link("Sign in")
  end
end
