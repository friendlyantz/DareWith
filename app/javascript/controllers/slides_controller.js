import { Controller } from "@hotwired/stimulus"

// Story-style slides: tap the right of the screen for the next one, the left third to go back
export default class extends Controller {
  static targets = ["slide", "ticks", "hint"]

  connect() {
    this.index = 0
    this.ticksTarget.replaceChildren(...this.slideTargets.map(() => {
      const tick = document.createElement("span")
      tick.className = "h-1 flex-1 rounded-full bg-neutral-content/30"
      return tick
    }))
    this.show()
  }

  tap(event) {
    if (event.target.closest("a, button")) return

    const { left, width } = this.element.getBoundingClientRect()
    if (event.clientX - left < width / 3) {
      this.go(this.index - 1)
    } else {
      this.go(this.index + 1)
    }
  }

  key(event) {
    if (event.key === "ArrowRight") this.go(this.index + 1)
    if (event.key === "ArrowLeft") this.go(this.index - 1)
  }

  go(index) {
    this.index = Math.max(0, Math.min(index, this.slideTargets.length - 1))
    this.show()
  }

  show() {
    const last = this.slideTargets.length - 1
    this.slideTargets.forEach((slide, index) => { slide.hidden = index !== this.index })
    Array.from(this.ticksTarget.children).forEach((tick, index) => {
      tick.classList.toggle("bg-neutral-content", index <= this.index)
      tick.classList.toggle("bg-neutral-content/30", index > this.index)
    })
    this.hintTarget.classList.toggle("invisible", this.index === last)
  }
}
