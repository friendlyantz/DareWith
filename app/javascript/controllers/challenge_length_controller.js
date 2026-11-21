import { Controller } from "@hotwired/stimulus"

const DAY = 86_400_000

// Sets the end date from a length chip ("4 weeks") so nobody does date maths,
// and spells the dates out under the chips. "Custom" shows the date fields instead.
export default class extends Controller {
  static targets = ["choice", "start", "finish", "cadence", "dates"]

  connect() {
    this.showDates()
  }

  choose() {
    const days = Number(this.chosen?.value)
    const start = this.parse(this.startTarget.value)
    if (days && start) this.finishTarget.value = this.isoDate(new Date(start.getFullYear(), start.getMonth(), start.getDate() + days - 1))
    this.showDates()
  }

  // 30 days isn't whole weeks, so a weekly challenge moves to 4 weeks
  keepWholeWeeks() {
    if (this.cadenceTarget.value !== "weekly" || Number(this.chosen?.value) % 7 === 0) return

    this.chosen.checked = false
    this.choiceTargets.find(it => it.value === "28").checked = true
    this.choose()
  }

  showDates() {
    const start = this.parse(this.startTarget.value)
    const finish = this.parse(this.finishTarget.value)
    if (!start || !finish) return

    this.datesTarget.textContent = `Starts ${this.relative(start)} · ends ${this.format(finish)}`
  }

  get chosen() {
    return this.choiceTargets.find(it => it.checked)
  }

  relative(date) {
    const days = Math.round((date - this.today()) / DAY)
    if (days === 0) return "today"
    if (days === 1) return "tomorrow"
    return this.format(date)
  }

  // "Sat 20 Dec"
  format(date) {
    return date.toLocaleDateString("en-GB", { weekday: "short", day: "numeric", month: "short" }).replace(",", "")
  }

  today() {
    const now = new Date()
    return new Date(now.getFullYear(), now.getMonth(), now.getDate())
  }

  parse(value) {
    const [year, month, day] = value.split("-").map(Number)
    return year ? new Date(year, month - 1, day) : null
  }

  isoDate(date) {
    return [date.getFullYear(), date.getMonth() + 1, date.getDate()].map(it => String(it).padStart(2, "0")).join("-")
  }
}
