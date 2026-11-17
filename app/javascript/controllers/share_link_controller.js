import { Controller } from "@hotwired/stimulus"
import { copyText } from "controllers/clipboard_controller"

// Native share sheet where available, otherwise copy the link and say so
export default class extends Controller {
  static values = { url: String }

  async nativeShare() {
    if (navigator.share) {
      navigator.share({ title: "Join my challenge on DareWith", url: this.urlValue }).catch(() => {})
      return
    }

    await copyText(this.urlValue)
    this.element.classList.add("tooltip", "tooltip-open", "tooltip-bottom")
    this.element.dataset.tip = "Invite link copied"
    setTimeout(() => this.element.classList.remove("tooltip-open"), 2000)
  }
}
