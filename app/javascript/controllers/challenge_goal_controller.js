import { Controller } from "@hotwired/stimulus"

// "30 minutes", "30+ min", "a 5 km run", "20-page"
const AMOUNT_AND_UNIT = /(\d+(?:\.\d+)?)\s*\+?\s*-?\s*(minutes?|mins?|hours?|hrs?|km|kilomet(?:re|er)s?|pages?|reps?)\b/i
const UNITS = { min: "minutes", h: "hours", k: "km", p: "pages", r: "reps" }

// Picks what to count from the title as it's typed ("walk the dog 30+ minutes"
// counts minutes, 30 a day) until the person picks a unit themselves,
// and spells the rules out next to the submit button so a wrong pick is easy to spot
export default class extends Controller {
  static targets = ["title", "cadence", "timesPerPeriod", "unit", "targetAmount", "targetScope", "start", "finish", "penaltyMode", "penalty", "repeats", "notes", "penaltyHint", "notesHint", "summary"]

  connect() {
    this.guessing = this.unitTarget.value === "" && !this.unitTarget.matches(":disabled")
    this.guessedAmount = ""
    this.summarize()
  }

  guess() {
    if (!this.guessing) return

    const [, amount = "", word] = this.titleTarget.value.match(AMOUNT_AND_UNIT) || []
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
    this.targetScopeTarget.querySelector("option[value='each_period']").text = `a ${this.periodName()}`
    const repeats = this.repeatsTarget.checked && "repeats"
    this.summaryTarget.textContent = [often, this.target(), this.penalty(), this.length(), repeats].filter(Boolean).join(" · ")
    this.penaltyHintTarget.textContent = this.penalty() || "Nothing happens"
    this.notesHintTarget.textContent = this.notesTarget.value.trim() || "Optional note, e.g. post a photo"
  }

  // Mirrors ChallengeStory::Penalty#summary
  penalty() {
    const mode = this.penaltyModeTargets.find(radio => radio.checked)?.value
    const owed = this.penaltyTarget.value.trim()
    if (!mode || !owed) return

    return `${mode === "per_miss" ? "Each miss" : "Most misses"}: owe everyone ${owed}`
  }

  length() {
    const start = Date.parse(this.startTarget.value)
    const finish = Date.parse(this.finishTarget.value)
    if (!start || !finish || finish < start) return

    const days = Math.round((finish - start) / 86_400_000) + 1
    if (this.cadenceTarget.value === "weekly" && days % 7 === 0) return days === 7 ? "1 week" : `${days / 7} weeks`
    return days === 1 ? "1 day" : `${days} days`
  }

  target() {
    const unit = this.unitTarget.value
    const amount = this.targetAmountTarget.value
    if (!unit) return "just check in"
    if (!amount) return `counting ${unit}`

    const label = (Number(amount) === 1 && unit !== "km") ? unit.replace(/s$/, "") : unit
    return `${amount} ${label} ${this.targetScopeTarget.value === "total" ? "each by the end" : `a ${this.periodName()}`}`
  }

  periodName() {
    return this.cadenceTarget.value === "weekly" ? "week" : "day"
  }

  unitFor(word) {
    const key = Object.keys(UNITS).find(prefix => word.toLowerCase().startsWith(prefix))
    return UNITS[key]
  }
}
