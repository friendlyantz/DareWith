import { Controller } from "@hotwired/stimulus"

// Submits the form as soon as a field changes
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
