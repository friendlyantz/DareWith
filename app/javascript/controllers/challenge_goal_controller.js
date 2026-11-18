import { Controller } from "@hotwired/stimulus"

// "30 minutes", "30+ min", "a 5 km run", "20-page"
const AMOUNT_AND_UNIT = /(\d+(?:\.\d+)?)\s*\+?\s*-?\s*(minutes?|mins?|hours?|hrs?|km|kilomet(?:re|er)s?|pages?|reps?)\b/i
const UNITS = { min: "minutes", h: "hours", k: "km", p: "pages", r: "reps" }

// Picks what to count from the title and rules as they're typed ("walk the dog 30+ minutes"
// counts minutes, 30 each time) until the person picks a unit themselves,
// and spells the goal out next to the submit button so a wrong pick is easy to spot
export default class extends Controller {
  static targets = ["text", "cadence", "timesPerPeriod", "unit", "targetAmount", "targetScope", "summary"]

  connect() {
    this.guessing = this.unitTarget.value === "" && !this.unitTarget.matches(":disabled")
    this.guessedAmount = ""
    this.summarize()
  }

  guess() {
    if (!this.guessing) return

    const [, amount = "", word] = this.textTargets.map(it => it.value).join("\n").match(AMOUNT_AND_UNIT) || []
    this.unitTarget.value = word ? this.unitFor(word) : ""
    if (this.targetAmountTarget.value === this.guessedAmount) {
      this.targetAmountTarget.value = this.guessedAmount = amount
    }
    this.summarize()
  }

  chooseUnit() {
    this.guessing = false
  }

  summarize() {
    const often = this.cadenceTarget.value === "weekly" ? `${this.timesPerPeriodTarget.value}× a week` : "Every day"
    this.summaryTarget.textContent = [often, this.target()].join(" · ")
  }

  target() {
    const unit = this.unitTarget.value
    const amount = this.targetAmountTarget.value
    if (!unit) return "just check in"
    if (!amount) return `counting ${unit}`

    const label = (Number(amount) === 1 && unit !== "km") ? unit.replace(/s$/, "") : unit
    return `${amount} ${label} ${this.targetScopeTarget.value === "total" ? "each by the end" : "each time"}`
  }

  unitFor(word) {
    const key = Object.keys(UNITS).find(prefix => word.toLowerCase().startsWith(prefix))
    return UNITS[key]
  }
}
