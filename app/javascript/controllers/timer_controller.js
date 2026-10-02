import { Controller } from "@hotwired/stimulus"

// A simple stopwatch that writes elapsed time into a decimal "hours" field.
export default class extends Controller {
  static targets = [ "display", "toggle", "hours" ]
  static values = { roundTo: { type: Number, default: 0.01 } }

  connect() {
    this.running = false
    this.seconds = 0
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
    this.startedAt = Date.now() - this.seconds * 1000
    this.timer = setInterval(() => this.tick(), 250)
    this.toggleTarget.textContent = "Stop timer"
    this.toggleTarget.classList.remove("btn--primary")
    this.toggleTarget.classList.add("btn--danger")
    this.tick()
  }

  stop() {
    if (!this.running) return

    this.running = false
    this.stopTicking()
    this.toggleTarget.textContent = "Start timer"
    this.toggleTarget.classList.add("btn--primary")
    this.toggleTarget.classList.remove("btn--danger")
    this.applyHours()
  }

  reset() {
    this.running = false
    this.stopTicking()
    this.seconds = 0
    this.toggleTarget.textContent = "Start timer"
    this.toggleTarget.classList.add("btn--primary")
    this.toggleTarget.classList.remove("btn--danger")
    if (this.hasHoursTarget) this.hoursTarget.value = ""
    this.render()
  }

  tick() {
    this.seconds = (Date.now() - this.startedAt) / 1000
    this.render()
    this.applyHours()
  }

  applyHours() {
    if (!this.hasHoursTarget) return

    const hours = this.seconds / 3600
    const rounded = Math.round(hours / this.roundToValue) * this.roundToValue
    this.hoursTarget.value = rounded.toFixed(2)
  }

  render() {
    if (!this.hasDisplayTarget) return

    const total = Math.floor(this.seconds)
    const hours = String(Math.floor(total / 3600)).padStart(2, "0")
    const minutes = String(Math.floor((total % 3600) / 60)).padStart(2, "0")
    const secs = String(total % 60).padStart(2, "0")

    this.displayTarget.textContent = `${hours}:${minutes}:${secs}`
  }

  stopTicking() {
    if (this.timer) {
      clearInterval(this.timer)
      this.timer = null
    }
  }
}
