import { Controller } from "@hotwired/stimulus"

// Helpers for the week grid: fill or clear the per-day hours inputs.
export default class extends Controller {
  static targets = [ "hours" ]
  static values = { defaultHours: { type: Number, default: 8 } }

  fillWeekdays() {
    this.hoursTargets.forEach(input => {
      if (input.dataset.weekday === "true") input.value = this.defaultHoursValue
    })
  }

  clear() {
    this.hoursTargets.forEach(input => { input.value = "" })
  }
}
