import { Controller } from "@hotwired/stimulus"
import { createConsumer } from "@rails/actioncable"

export default class extends Controller {
  static targets = ["connectionStatus", "currentStatus", "eventLog", "eventCount", "rawPayload"]

  connect() {
    this.consumer = createConsumer()
    this.subscription = this.consumer.subscriptions.create("SnooEventsChannel", {
      received: (data) => this.handleMessage(data)
    })
  }

  disconnect() {
    this.subscription?.unsubscribe()
    this.consumer?.disconnect()
  }

  handleMessage(data) {
    if (data.html) {
      this.eventLogTarget.insertAdjacentHTML("afterbegin", data.html)

      // Update event count
      const rows = this.eventLogTarget.querySelectorAll("tr")
      this.eventCountTarget.textContent = `${rows.length} events`
    }

    if (data.status_html) {
      this.currentStatusTarget.innerHTML = data.status_html
    }

    if (data.connection_status) {
      const el = this.connectionStatusTarget
      if (data.connection_status === "connected") {
        el.textContent = "Connected"
        el.className = "px-3 py-1 rounded-full text-sm font-medium bg-green-100 text-green-800"
      } else if (data.connection_status === "error") {
        el.textContent = `Error: ${data.error}`
        el.className = "px-3 py-1 rounded-full text-sm font-medium bg-red-100 text-red-800"
      } else {
        el.textContent = "Disconnected"
        el.className = "px-3 py-1 rounded-full text-sm font-medium bg-gray-100 text-gray-800"
      }
    }
  }

  showPayload(event) {
    const row = event.currentTarget
    const raw = row.dataset.raw
    if (raw && this.hasRawPayloadTarget) {
      try {
        this.rawPayloadTarget.textContent = JSON.stringify(JSON.parse(raw), null, 2)
      } catch {
        this.rawPayloadTarget.textContent = raw
      }
    }
  }
}
