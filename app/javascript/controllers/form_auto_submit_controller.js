import { Controller } from "@hotwired/stimulus"

// Submits the form whenever one of its inputs changes. Used for filter bars
// that reload the page with new query parameters.
export default class extends Controller {
  submit() {
    this.element.requestSubmit()
  }
}
