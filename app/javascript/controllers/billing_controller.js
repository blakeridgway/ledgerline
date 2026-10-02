import { Controller } from "@hotwired/stimulus"

// Shows the fields that match the selected billing type. Targets are plural
// because several fields belong to the "monthly" group.
export default class extends Controller {
  static targets = [ "billingType", "hourly", "monthly" ]

  connect() {
    this.update()
  }

  update() {
    const hourly = this.billingTypeTarget.value === "hourly"

    this.hourlyTargets.forEach(element => { element.hidden = !hourly })
    this.monthlyTargets.forEach(element => { element.hidden = hourly })
  }
}
