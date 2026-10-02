import { Controller } from "@hotwired/stimulus"

// Keeps the invoice preview in sync with the form. Auto-refreshing works by
// pressing the preview button, so the request goes through Turbo's frame
// submission path (a 200 response is valid there, unlike a full page submit).
export default class extends Controller {
  static targets = [ "button" ]

  refresh() {
    if (!this.hasButtonTarget) return
    if (this.buttonTarget.disabled) return

    this.buttonTarget.click()
  }
}
