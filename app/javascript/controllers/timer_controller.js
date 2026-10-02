import { Controller } from "@hotwired/stimulus"

// A stopwatch that writes net worked time into a decimal "hours" field. Work
// and break time are kept as separate accumulators, so taking a break pauses
// the worked clock — and therefore the hours that get billed — while a break
// clock keeps running.
export default class extends Controller {
  static targets = [ "display", "toggle", "break", "hours", "hint", "breakDisplay" ]
  static values = { roundTo: { type: Number, default: 0.01 } }

  connect() {
    this.running = false
    this.onBreak = false
    this.workedSeconds = 0
    this.breakSeconds = 0
    this.segmentStartedAt = null
    this.render()
  }

  disconnect() {
    this.stopTicking()
  }

  toggle() {
    this.running ? this.stop() : this.start()
  }

  start() {
    if (this.running) return

    this.running = true
    this.onBreak = false
    this.segmentStartedAt = Date.now()
    this.timer = setInterval(() => this.tick(), 250)
    this.tick()
  }

  stop() {
    if (!this.running) return

    this.commitSegment()
    this.running = false
    this.onBreak = false
    this.segmentStartedAt = null
    this.stopTicking()
    this.applyHours()
    this.render()
  }

  // Pauses the worked clock and starts a break; pressing again resumes work.
  toggleBreak() {
    if (!this.running) return

    this.commitSegment()
    this.onBreak = !this.onBreak
    this.segmentStartedAt = Date.now()
    this.render()
  }

  reset() {
    this.running = false
    this.onBreak = false
    this.workedSeconds = 0
    this.breakSeconds = 0
    this.segmentStartedAt = null
    this.stopTicking()
    if (this.hasHoursTarget) this.hoursTarget.value = ""
    this.render()
  }

  tick() {
    this.render()
    if (!this.onBreak) this.applyHours()
  }

  // Moves the time elapsed in the current segment into its accumulator so it
  // survives the next segment starting.
  commitSegment() {
    if (this.segmentStartedAt === null) return

    const elapsed = (Date.now() - this.segmentStartedAt) / 1000
    if (this.onBreak) {
      this.breakSeconds += elapsed
    } else {
      this.workedSeconds += elapsed
    }
    this.segmentStartedAt = Date.now()
  }

  applyHours() {
    if (!this.hasHoursTarget) return

    const hours = this.workedTotal() / 3600
    const rounded = Math.round(hours / this.roundToValue) * this.roundToValue
    this.hoursTarget.value = rounded.toFixed(2)
  }

  render() {
    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = this.format(this.workedTotal())
    }

    if (this.hasToggleTarget) {
      this.toggleTarget.textContent = this.running ? "Stop timer" : "Start timer"
      this.toggleTarget.classList.toggle("btn--primary", !this.running)
      this.toggleTarget.classList.toggle("btn--danger", this.running)
    }

    if (this.hasBreakTarget) {
      this.breakTarget.disabled = !this.running
      this.breakTarget.textContent = this.onBreak ? "Resume" : "Take break"
      this.breakTarget.classList.toggle("btn--primary", this.onBreak)
    }

    if (this.hasBreakDisplayTarget) {
      const breakSeconds = this.breakTotal()
      this.breakDisplayTarget.textContent = breakSeconds >= 1 ? `Break ${this.format(breakSeconds)}` : ""
    }

    if (this.hasHintTarget) {
      this.hintTarget.textContent = this.onBreak
        ? "On break — the clock is paused."
        : "Stop the timer to fill in the hours field."
    }
  }

  workedTotal() {
    return this.workedSeconds + this.activeSegmentSeconds(!this.onBreak)
  }

  breakTotal() {
    return this.breakSeconds + this.activeSegmentSeconds(this.onBreak)
  }

  activeSegmentSeconds(active) {
    if (!active || !this.running || this.segmentStartedAt === null) return 0

    return (Date.now() - this.segmentStartedAt) / 1000
  }

  stopTicking() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }

  format(seconds) {
    const total = Math.floor(seconds)
    const hours = String(Math.floor(total / 3600)).padStart(2, "0")
    const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0")
    const secs = String(total % 60).padStart(2, "0")
    return `${hours}:${minutes}:${secs}`
  }
}
