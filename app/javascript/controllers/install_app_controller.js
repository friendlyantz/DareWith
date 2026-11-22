import { Controller } from "@hotwired/stimulus"

// "Add to Home Screen" for browsers that can install the app themselves (Chrome, Edge,
// Samsung Internet). Stays hidden on iPhone, which has no install button to press, and
// inside the installed app.
export default class extends Controller {
  connect() {
    this.refresh()
  }

  refresh() {
    this.element.hidden = !window.installAppPrompt || this.isInstalled()
  }

  isInstalled() {
    return window.matchMedia("(display-mode: standalone)").matches
  }

  async install() {
    const installPrompt = window.installAppPrompt
    if (!installPrompt) return this.refresh()

    // Chrome lets each offer be shown once
    window.installAppPrompt = null
    installPrompt.prompt()
    await installPrompt.userChoice
    this.refresh()
  }

  // "Later": the banner stays away for a month; the card on Me stays
  dismiss() {
    const expires = new Date(Date.now() + 30 * 24 * 60 * 60 * 1000).toUTCString()
    document.cookie = `install_app_dismissed=true; expires=${expires}; path=/`
    this.element.remove()
  }
}
