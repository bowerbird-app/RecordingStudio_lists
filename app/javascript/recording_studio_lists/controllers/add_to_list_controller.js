import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["check"]

  async toggle(event) {
    const item = event.currentTarget
    const form = document.getElementById(item?.getAttribute("form") || "")
    if (!form || item.dataset.pending === "true") return

    event.preventDefault()
    item.dataset.pending = "true"
    const token = document.querySelector("meta[name='csrf-token']")?.content
    try {
      const response = await fetch(form.action, {
        method: "POST",
        body: new FormData(form),
        headers: {
          "Accept": "text/html",
          "X-CSRF-Token": token || "",
          "X-Lists-Menu": "1"
        },
        credentials: "same-origin"
      })
      if (!response.ok) return

      this.flip(item, form)
    } finally {
      delete item.dataset.pending
    }
  }

  flip(item, form) {
    const removing = form.querySelector("[name='_method']")?.value === "delete"
    if (removing) {
      item.querySelector("[data-flat-pack--icon-name-value='check']")?.remove()
      form.setAttribute("action", form.dataset.addUrl)
      form.querySelector("[name='_method']")?.remove()
      return
    }

    if (!item.querySelector("[data-flat-pack--icon-name-value='check']")) {
      const icon = this.checkTarget.content.querySelector("svg")?.cloneNode(true)
      if (icon) item.append(icon)
    }
    form.setAttribute("action", form.dataset.removeUrl)
    if (!form.querySelector("[name='_method']")) {
      const input = document.createElement("input")
      input.type = "hidden"
      input.name = "_method"
      input.value = "delete"
      form.prepend(input)
    }
  }
}
