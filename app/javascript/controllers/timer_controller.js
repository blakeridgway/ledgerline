import { Controller } from "@hotwired/stimulus"
import { Stopwatch } from "lib/stopwatch"

// Thin DOM adapter around the pure Stopwatch state machine. It maps the
// controls to start/stop/break and renders worked and break time. The billing
// arithmetic (net worked hours) lives in lib/stopwatch and is unit-tested.
export default class extends Controller {
  static targets = [ "display", "toggle", "break", "hours", "breakMinutes", "hint", "breakDisplay" ]
  static values = { roundTo: { type: Number, default: 0.01 } }

  connect() {
    this.stopwatch = new Stopwatch({ roundTo: this.roundToValue })
    this.render()
  }

  disconnect() {
    this.stopTicking()
  }

  toggle() {
    this.stopwatch.running ? this.stop() : this.start()
  }

  start() {
    if (this.stopwatch.running) return

    this.stopwatch.start()
    this.timer = setInterval(() => this.tick(), 250)
    this.tick()
  }

  stop() {
    if (!this.stopwatch.running) return

    this.stopwatch.stop()
    this.stopTicking()
    this.applyBreakMinutes()
    this.applyHours()
    this.render()
  }

  toggleBreak() {
    if (!this.stopwatch.running) return

    this.stopwatch.toggleBreak()
    this.render()
  }

  reset() {
    this.stopwatch.reset()
    this.stopTicking()
    if (this.hasHoursTarget) this.hoursTarget.value = ""
    if (this.hasBreakMinutesTarget) this.breakMinutesTarget.value = "0"
    this.render()
  }

  tick() {
    this.render()
    this.applyBreakMinutes()
    if (!this.stopwatch.onBreak) this.applyHours()
  }

  applyHours() {
    if (!this.hasHoursTarget) return

    this.hoursTarget.value = this.stopwatch.workedHours().toFixed(2)
  }

  applyBreakMinutes() {
    if (!this.hasBreakMinutesTarget) return

    this.breakMinutesTarget.value = this.stopwatch.breakMinutes()
  }

  render() {
    const watch = this.stopwatch

    if (this.hasDisplayTarget) {
      this.displayTarget.textContent = this.format(watch.workedSeconds)
    }

    if (this.hasToggleTarget) {
      this.toggleTarget.textContent = watch.running ? "Stop timer" : "Start timer"
      this.toggleTarget.classList.toggle("btn--primary", !watch.running)
      this.toggleTarget.classList.toggle("btn--danger", watch.running)
    }

    if (this.hasBreakTarget) {
      this.breakTarget.disabled = !watch.running
      this.breakTarget.textContent = watch.onBreak ? "Resume" : "Take break"
      this.breakTarget.classList.toggle("btn--primary", watch.onBreak)
    }

    if (this.hasBreakDisplayTarget) {
      const breakSeconds = watch.breakSeconds
      this.breakDisplayTarget.textContent = breakSeconds >= 1 ? `Break ${this.format(breakSeconds)}` : ""
    }

    if (this.hasHintTarget) {
      this.hintTarget.textContent = watch.onBreak
        ? "On break — the clock is paused."
        : "Stop the timer to fill in the hours field."
    }
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
