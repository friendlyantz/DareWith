require "system_helper"

RSpec.describe "Installing the app", type: :system do
  let(:user) { create(:user) }

  before do
    create(:challenge_participant, user: user)
    sign_in_as(user)
  end

  # What Chrome does once it decides the site can be installed
  def offer_install
    page.execute_script(<<~JS)
      const offer = new Event("beforeinstallprompt")
      offer.prompt = () => { window.installPromptShown = true }
      offer.userChoice = Promise.resolve({ outcome: "accepted" })
      window.dispatchEvent(offer)
    JS
  end

  scenario "Me offers to install once the browser can, and the offer is used up" do
    visit profile_path

    expect(page).to have_no_content("Add DareWith to your Home Screen")

    offer_install

    click_on "Add"

    expect(page.evaluate_script("window.installPromptShown")).to be(true)
    expect(page).to have_no_content("Add DareWith to your Home Screen")
  end

  scenario "Later keeps the banner away on the next pages" do
    visit today_path
    offer_install

    within("[data-controller='install-app']") { click_on "Later" }
    visit today_path
    offer_install

    expect(page).to have_no_content("Add DareWith to your Home Screen")
  end
end
