import { Controller } from "@hotwired/stimulus"

// Shows the author's own controls on a check-in posted today. Cards also arrive
// through broadcasts that don't know who is looking, so this decides in the browser.
// The server checks again on delete.
export default class extends Controller {
  static targets = ["controls"]
  static values = { userId: String, day: String }

  connect() {
    const currentUserId = document.querySelector('meta[name="current-user-id"]')?.content
    if (currentUserId !== this.userIdValue || this.dayValue !== this.today()) return

    this.controlsTargets.forEach(target => target.hidden = false)
  }

  today() {
    const now = new Date()
    const pad = number => String(number).padStart(2, "0")
    return `${now.getFullYear()}-${pad(now.getMonth() + 1)}-${pad(now.getDate())}`
  }
}
