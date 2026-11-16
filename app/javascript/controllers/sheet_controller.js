import { Controller } from "@hotwired/stimulus"

// Bottom sheet whose content loads into a turbo frame.
// After a successful form submit inside it, the sheet closes and the page refreshes.
// Forms marked data-sheet-stay-open keep the sheet open to show the response; closing it then refreshes.
export default class extends Controller {
  static targets = ["dialog", "frame"]

  connect() {
    this.placeholder = this.frameTarget.innerHTML
  }

  open() {
    this.dialogTarget.showModal()
  }

  submitted(event) {
    if (!event.detail.success) return

    this.submittedSuccessfully = true
    if (event.target.dataset.sheetStayOpen) return

    this.dialogTarget.close()
  }

  reset() {
    this.frameTarget.removeAttribute("src")
    this.frameTarget.innerHTML = this.placeholder

    if (this.submittedSuccessfully) {
      this.submittedSuccessfully = false
      Turbo.visit(window.location.href, { action: "replace" })
    }
  }
}
