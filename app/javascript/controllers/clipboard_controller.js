import { Controller } from "@hotwired/stimulus"

// Copies textValue to the clipboard and briefly confirms on the button
export default class extends Controller {
  static values = { text: String, copied: { type: String, default: "Copied!" } }

  async copy() {
    await copyText(this.textValue)

    const label = this.element.textContent
    this.element.textContent = this.copiedValue
    setTimeout(() => { this.element.textContent = label }, 2000)
  }
}

export async function copyText(text) {
  try {
    await navigator.clipboard.writeText(text)
  } catch {
    // Older in-app browsers: fall back to a hidden textarea
    const textarea = document.createElement("textarea")
    textarea.value = text
    textarea.setAttribute("readonly", "")
    textarea.style.position = "absolute"
    textarea.style.left = "-9999px"
    document.body.appendChild(textarea)
    textarea.select()
    document.execCommand("copy")
    textarea.remove()
  }
}
