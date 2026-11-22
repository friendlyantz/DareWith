import { Controller } from "@hotwired/stimulus"
import { copyText } from "controllers/clipboard_controller"
import { shareInApp } from "native_share"

// Native share sheet where available, otherwise copy the link and say so
export default class extends Controller {
  static values = { url: String }

  async nativeShare() {
    const title = "Join my challenge on DareWith"
    if (shareInApp({ title, text: this.urlValue })) return

    if (navigator.share) {
      navigator.share({ title, url: this.urlValue }).catch(() => {})
      return
    }

    await copyText(this.urlValue)
    this.element.classList.add("tooltip", "tooltip-open", "tooltip-bottom")
    this.element.dataset.tip = "Invite link copied"
    setTimeout(() => this.element.classList.remove("tooltip-open"), 2000)
  }
}
