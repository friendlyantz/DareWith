import { Controller } from "@hotwired/stimulus"

// Closes the surrounding sheet after a moment (if given), or on any tap, e.g. a plain "Checked in".
// Outside a sheet, e.g. the page opened in its own tab, links inside just navigate.
export default class extends Controller {
  static values = { after: Number }

  connect() {
    if (this.afterValue) this.timeout = setTimeout(() => this.close(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  // Something inside wants the sheet to stay, e.g. sharing the progress card
  stay() {
    clearTimeout(this.timeout)
  }

  close(event) {
    const dialog = this.element.closest("dialog")
    if (!dialog) return

    event?.preventDefault()
    dialog.close()
  }
}
