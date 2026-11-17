import { Controller } from "@hotwired/stimulus"

// Closes the surrounding sheet after a moment, or on any tap, e.g. a plain "Checked in"
export default class extends Controller {
  static values = { after: { type: Number, default: 2000 } }

  connect() {
    this.timeout = setTimeout(() => this.close(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }

  close() {
    this.element.closest("dialog")?.close()
  }
}
