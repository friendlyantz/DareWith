require "system_helper"

RSpec.describe "Home Page", type: :system do
  let(:home_page) { prism.library.home }

  scenario "visitor sees the landing page" do
    home_page.load

    expect(page).to have_content(/Dare Your (Mates|Friends)/)
    expect(page).to have_content("DareWith")
  end

  scenario "visitor is pointed to sign up, never sign in" do
    home_page.load

    expect(page).to have_link("Get started", href: new_webauthn_registration_path, count: 2)
    expect(home_page.dock).to have_link("Sign up", href: new_webauthn_registration_path)
    expect(page).to have_no_link(href: new_webauthn_session_path)
  end
end
