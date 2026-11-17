import { Controller } from "@hotwired/stimulus"

// Offers "Doubt it" on a friend's check-in while doubts are open, and "Withdraw doubt" to
// whoever doubted it. Cards also arrive through broadcasts that don't know who is looking,
// so this decides in the browser. The server checks again.
export default class extends Controller {
  static targets = ["doubt", "withdraw"]
  static values = { authorId: String, doubterIds: Array, closesAt: String }

  connect() {
    this.refresh()
  }

  // A morph refresh puts back the server's hidden attributes
  refresh() {
    const currentUserId = document.querySelector('meta[name="current-user-id"]')?.content
    const open = currentUserId && currentUserId !== this.authorIdValue && new Date() < new Date(this.closesAtValue)
    const doubted = this.doubterIdsValue.includes(currentUserId)

    this.doubtTarget.hidden = !open || doubted
    this.withdrawTarget.hidden = !open || !doubted
  }
}
