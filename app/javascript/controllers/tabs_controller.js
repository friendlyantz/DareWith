import { Controller } from "@hotwired/stimulus"

// Keeps the selected radio tab when the page refreshes itself (e.g. after a check-in or pledge)
export default class extends Controller {
  connect() {
    this.restore()
  }

  remember(event) {
    // Forms inside the tab panels bubble change events too; only the tab radios count
    if (!event.target.matches('input[type="radio"].tab')) return

    try { sessionStorage.setItem(this.key, event.target.id) } catch {}
  }

  restore() {
    let id
    try { id = sessionStorage.getItem(this.key) } catch {}
    const input = id && document.getElementById(id)
    if (input && this.element.contains(input)) input.checked = true
  }

  get key() {
    return `tab:${window.location.pathname}`
  }
}
