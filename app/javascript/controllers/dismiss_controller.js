import { Controller } from "@hotwired/stimulus"

// Removes the element after a few seconds, e.g. a flash toast
export default class extends Controller {
  static values = { after: { type: Number, default: 4000 } }

  connect() {
    this.timeout = setTimeout(() => this.element.remove(), this.afterValue)
  }

  disconnect() {
    clearTimeout(this.timeout)
  }
}
