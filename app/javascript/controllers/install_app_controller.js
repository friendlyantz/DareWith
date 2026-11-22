import { Controller } from "@hotwired/stimulus"

// "Add to Home Screen" for browsers that can install the app themselves (Chrome, Edge,
// Samsung Internet). Stays hidden on iPhone, which has no install button to press, inside
// the installed app, and in a browser where the app has already been installed or opened.
export default class extends Controller {
  connect() {
    this.refresh()
  }

  refresh() {
    this.element.hidden = !window.installAppPrompt || this.isInstalled()
  }

  isInstalled() {
    return window.matchMedia("(display-mode: standalone)").matches ||
      document.cookie.includes("app_installed=true")
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

  // "Later": the banner stays away for a week, like the notifications one; the card on Me stays
  dismiss() {
    const expires = new Date(Date.now() + 7 * 24 * 60 * 60 * 1000).toUTCString()
    document.cookie = `install_app_dismissed=true; expires=${expires}; path=/`
    this.element.remove()
  }
}
