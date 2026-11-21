import { Controller } from "@hotwired/stimulus"

// Keeps the selected radio tab when the page refreshes itself (e.g. after a check-in or pledge),
// and opens the tab holding the linked item when arriving from a link like an alert (/challenge_stories/1#challenge_check_in_5)
export default class extends Controller {
  connect() {
    if (!this.openLinkedTab()) this.restore()
  }

  remember(event) {
    // Forms inside the tab panels bubble change events too; only the tab radios count
    if (!event.target.matches('input[type="radio"].tab')) return

    this.save(event.target.id)
  }

  restore() {
    let id
    try { id = sessionStorage.getItem(this.key) } catch {}
    const input = id && document.getElementById(id)
    if (input && this.element.contains(input)) input.checked = true
  }

  openLinkedTab() {
    const target = window.location.hash && document.getElementById(decodeURIComponent(window.location.hash.slice(1)))
    const input = target && this.element.contains(target) && target.closest(".tab-content")?.previousElementSibling
    if (!input?.matches('input[type="radio"].tab')) return false

    input.checked = true
    this.save(input.id)
    target.scrollIntoView({ block: "center" })
    return true
  }

  save(id) {
    try { sessionStorage.setItem(this.key, id) } catch {}
  }

  get key() {
    return `tab:${window.location.pathname}`
  }
}
