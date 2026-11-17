import ShareCardController, { WIDTH, HEIGHT, PADDING, PRIMARY, NEUTRAL, DISPLAY, SANS } from "controllers/share_card_controller"

const GAP = 16

// The finish card: a collage of the challenge's photos over the participant's final numbers.
// Sharing, fonts and the plain fallback come from the progress card.
export default class extends ShareCardController {
  static values = { photoUrls: Array, stats: Array }

  get fileName() {
    return "darewith-finish.png"
  }

  get shareText() {
    return `I finished ${this.titleValue}! Dare with me ${this.urlValue}`
  }

  drawBackground(context, photos) {
    const gradient = context.createLinearGradient(0, 0, WIDTH, HEIGHT)
    gradient.addColorStop(0, PRIMARY)
    gradient.addColorStop(1, NEUTRAL)
    context.fillStyle = gradient
    context.fillRect(0, 0, WIDTH, HEIGHT)
    // Drawn after the text, which decides how much room the collage gets
    this.photos = photos
  }

  // Built from the bottom up, so a long title pushes the collage smaller
  drawText(context) {
    const width = WIDTH - PADDING * 2
    context.fillStyle = "#ffffff"
    context.textBaseline = "alphabetic"

    context.font = `700 60px ${DISPLAY}`
    context.fillText("darewith", PADDING, 170)

    let y = HEIGHT - 130
    context.font = `600 44px ${SANS}`
    context.globalAlpha = 0.85
    context.fillText("Dare with me on darewith.app", PADDING, y)

    y -= 46
    this.statsValue.toReversed().forEach((line) => {
      y -= 64
      context.fillText(this.wrap(context, line, width, 1)[0], PADDING, y)
    })
    context.globalAlpha = 1

    y -= 100
    context.globalAlpha = 0.25
    this.roundedRect(context, PADDING, y, width, 28)
    context.globalAlpha = 1
    context.fillStyle = PRIMARY
    this.roundedRect(context, PADDING, y, Math.max(28, width * this.progressValue), 28)
    context.fillStyle = "#ffffff"

    y -= 50
    context.font = `600 52px ${SANS}`
    context.fillText(this.captionValue, PADDING, y)

    y -= 90
    this.drawHeadline(context, y, width)

    y -= 240
    context.font = `500 44px ${SANS}`
    context.globalAlpha = 0.85
    context.fillText(`${this.nameValue} · that's a wrap`, PADDING, y)
    context.globalAlpha = 1

    y -= 90
    context.font = `700 80px ${DISPLAY}`
    const lines = this.wrap(context, this.titleValue, width, 2).reverse()
    lines.forEach((line, index) => context.fillText(line, PADDING, y - index * 92))

    const collageTop = 230
    const collageBottom = y - (lines.length - 1) * 92 - 80 - 60
    this.drawCollage(context, collageTop, collageBottom - collageTop)
  }

  // Two columns; an odd photo out spans the full width at the bottom
  drawCollage(context, top, height) {
    const width = WIDTH - PADDING * 2
    const photos = this.photos || []

    if (photos.length === 0) {
      context.font = `${Math.round(height * 0.45)}px ${DISPLAY}`
      context.textAlign = "center"
      context.fillText("🏆", WIDTH / 2, top + height * 0.65)
      context.textAlign = "start"
      return
    }

    const columns = photos.length === 1 ? 1 : 2
    const rows = Math.ceil(photos.length / columns)
    const cellHeight = (height - GAP * (rows - 1)) / rows
    const cellWidth = (width - GAP * (columns - 1)) / columns

    photos.forEach((photo, index) => {
      const row = Math.floor(index / columns)
      const column = index % columns
      const wide = index === photos.length - 1 && column === 0
      const x = PADDING + column * (cellWidth + GAP)
      this.drawCover(context, photo, x, top + row * (cellHeight + GAP), wide ? width : cellWidth, cellHeight)
    })
  }

  drawCover(context, photo, x, y, width, height) {
    const scale = Math.max(width / photo.width, height / photo.height)
    const drawnWidth = photo.width * scale
    const drawnHeight = photo.height * scale

    context.save()
    context.beginPath()
    context.roundRect(x, y, width, height, 32)
    context.clip()
    context.drawImage(photo, x + (width - drawnWidth) / 2, y + (height - drawnHeight) / 2, drawnWidth, drawnHeight)
    context.restore()
  }

  async loadPhoto() {
    const photos = await Promise.all(this.photoUrlsValue.map((url) => new Promise((resolve) => {
      const image = new Image()
      image.crossOrigin = "anonymous"
      image.onload = () => resolve(image)
      image.onerror = () => resolve(null)
      image.src = url
    })))
    return photos.filter(Boolean)
  }
}
