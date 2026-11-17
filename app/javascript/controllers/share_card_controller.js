import { Controller } from "@hotwired/stimulus"
import { copyText } from "controllers/clipboard_controller"

const WIDTH = 1080
const HEIGHT = 1920
const PADDING = 96
const PRIMARY = "#c2410c"
const NEUTRAL = "#17181a"
const DISPLAY = '"Space Grotesk", ui-sans-serif, system-ui, sans-serif'
const SANS = '"Inter", ui-sans-serif, system-ui, sans-serif'

// Draws a story-sized progress card and opens the share sheet with it, or downloads it.
// The card is drawn on connect, because iOS only shares straight from the tap.
export default class extends Controller {
  static values = {
    title: String, name: String, headline: String, caption: String, emoji: String,
    progressLabel: String, progress: Number, url: String, photoUrl: String
  }

  connect() {
    this.card = this.draw()
  }

  // Instagram drops text shared with an image, so the link also goes on the clipboard for a Link sticker
  async share() {
    copyText(this.urlValue)
    this.confirmCopied()
    const file = new File([await this.card], "darewith-progress.png", { type: "image/png" })

    if (navigator.canShare?.({ files: [file] })) {
      navigator.share({ files: [file], text: `${this.titleValue}: join me ${this.urlValue}` }).catch(() => {})
    } else {
      this.download(file)
    }
  }

  confirmCopied() {
    this.element.classList.add("tooltip", "tooltip-open", "tooltip-top")
    this.element.dataset.tip = "Link copied for a Link sticker"
    clearTimeout(this.tooltipTimeout)
    this.tooltipTimeout = setTimeout(() => this.element.classList.remove("tooltip-open"), 5000)
  }

  async draw() {
    await Promise.all([`700 10px ${DISPLAY}`, `600 10px ${SANS}`].map((font) => document.fonts.load(font).catch(() => {})))
    const photo = await this.loadPhoto()

    try {
      return await this.render(photo)
    } catch {
      // A photo served without CORS taints the canvas, so fall back to the plain card
      return this.render(null)
    }
  }

  render(photo) {
    const canvas = document.createElement("canvas")
    canvas.width = WIDTH
    canvas.height = HEIGHT
    const context = canvas.getContext("2d")

    this.drawBackground(context, photo)
    this.drawText(context)

    return new Promise((resolve, reject) => {
      try {
        canvas.toBlob((blob) => blob ? resolve(blob) : reject(), "image/png")
      } catch (error) {
        reject(error)
      }
    })
  }

  drawBackground(context, photo) {
    if (photo) {
      const scale = Math.max(WIDTH / photo.width, HEIGHT / photo.height)
      const width = photo.width * scale
      const height = photo.height * scale
      context.drawImage(photo, (WIDTH - width) / 2, (HEIGHT - height) / 2, width, height)

      const shade = context.createLinearGradient(0, 0, 0, HEIGHT)
      shade.addColorStop(0, "rgba(23, 24, 26, 0.55)")
      shade.addColorStop(0.45, "rgba(23, 24, 26, 0.35)")
      shade.addColorStop(1, "rgba(23, 24, 26, 0.92)")
      context.fillStyle = shade
    } else {
      const gradient = context.createLinearGradient(0, 0, WIDTH, HEIGHT)
      gradient.addColorStop(0, PRIMARY)
      gradient.addColorStop(1, NEUTRAL)
      context.fillStyle = gradient
    }
    context.fillRect(0, 0, WIDTH, HEIGHT)
  }

  drawText(context) {
    const width = WIDTH - PADDING * 2
    context.fillStyle = "#ffffff"
    context.textBaseline = "alphabetic"

    context.font = `700 60px ${DISPLAY}`
    context.fillText("darewith", PADDING, 190)

    // Built from the bottom up, so a long title pushes upwards
    let y = HEIGHT - 150
    context.font = `600 44px ${SANS}`
    context.globalAlpha = 0.85
    context.fillText("Dare with me on darewith.app", PADDING, y)

    y -= 150
    context.globalAlpha = 0.25
    this.roundedRect(context, PADDING, y, width, 28)
    context.globalAlpha = 1
    context.fillStyle = PRIMARY
    this.roundedRect(context, PADDING, y, Math.max(28, width * this.progressValue), 28)
    context.fillStyle = "#ffffff"

    y -= 40
    context.font = `600 48px ${SANS}`
    context.fillText(this.progressLabelValue, PADDING, y)

    y -= 150
    context.font = `600 56px ${SANS}`
    context.globalAlpha = 0.85
    context.fillText(this.captionValue, PADDING, y)
    context.globalAlpha = 1

    y -= 90
    this.drawHeadline(context, y, width)

    y -= 290
    context.font = `500 48px ${SANS}`
    context.globalAlpha = 0.85
    context.fillText(this.nameValue, PADDING, y)
    context.globalAlpha = 1

    context.font = `700 92px ${DISPLAY}`
    const lines = this.wrap(context, this.titleValue, width, 3)
    lines.reverse().forEach((line, index) => context.fillText(line, PADDING, y - 90 - index * 104))
  }

  // Emoji fonts draw bigger than the text and dip below the baseline (very much so on Android),
  // so the emoji is drawn on its own at the number's height, resting on the baseline
  drawHeadline(context, y, width) {
    let x = PADDING
    let size = 240

    if (this.emojiValue) {
      context.font = `${Math.round(size * 0.62)}px ${DISPLAY}`
      const emoji = context.measureText(this.emojiValue)
      context.fillText(this.emojiValue, x, y - emoji.actualBoundingBoxDescent)
      x += emoji.width + 40
    }

    size = this.fitFontSize(context, this.headlineValue, PADDING + width - x, size)
    context.font = `700 ${size}px ${DISPLAY}`
    context.fillText(this.headlineValue, x, y)
  }

  fitFontSize(context, text, width, size) {
    context.font = `700 ${size}px ${DISPLAY}`
    const measured = context.measureText(text).width
    return measured > width ? Math.floor(size * width / measured) : size
  }

  wrap(context, text, width, maxLines) {
    const lines = []
    let line = ""
    for (const word of text.split(/\s+/)) {
      const candidate = line ? `${line} ${word}` : word
      if (line && context.measureText(candidate).width > width) {
        lines.push(line)
        line = word
      } else {
        line = candidate
      }
    }
    lines.push(line)

    if (lines.length > maxLines) {
      lines.length = maxLines
      lines[maxLines - 1] = `${lines[maxLines - 1].replace(/\s+\S*$/, "")}…`
    }
    return lines
  }

  roundedRect(context, x, y, width, height) {
    context.beginPath()
    context.roundRect(x, y, width, height, height / 2)
    context.fill()
  }

  loadPhoto() {
    if (!this.photoUrlValue) return Promise.resolve(null)

    return new Promise((resolve) => {
      const image = new Image()
      image.crossOrigin = "anonymous"
      image.onload = () => resolve(image)
      image.onerror = () => resolve(null)
      image.src = this.photoUrlValue
    })
  }

  download(file) {
    const link = document.createElement("a")
    link.href = URL.createObjectURL(file)
    link.download = file.name
    link.click()
    setTimeout(() => URL.revokeObjectURL(link.href), 1000)
  }
}
