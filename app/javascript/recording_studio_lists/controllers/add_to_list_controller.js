import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = ["check", "row"]

  connect() {
    this.menu = this.element.querySelector("[role=menu]")
    this.revealButton = this.element.querySelector("[data-recording-studio-lists--add-to-list-target='reveal']")
    this.createForm = this.element.querySelector("[data-recording-studio-lists--add-to-list-target='create']")
    this.nameInput = this.createForm?.querySelector("[data-recording-studio-lists--add-to-list-target='name']")
    this.errorMessage = this.createForm?.querySelector("[data-recording-studio-lists--add-to-list-target='error']")
    this.divider = this.element.querySelector("[data-recording-studio-lists--add-to-list-target='divider']")
    this.boundReveal = (event) => this.reveal(event)
    this.boundCreate = (event) => this.create(event)
    this.boundClearError = () => this.clearError()

    if (this.menu && this.createForm && this.createForm.parentElement !== this.menu) {
      this.menu.append(this.createForm)
    }

    // A menu row dismisses the menu. This one only opens the name field.
    this.revealButton?.removeAttribute("role")
    this.revealButton?.addEventListener("click", this.boundReveal)
    this.createForm?.addEventListener("submit", this.boundCreate)
    this.nameInput?.addEventListener("input", this.boundClearError)
  }

  disconnect() {
    this.revealButton?.removeEventListener("click", this.boundReveal)
    this.createForm?.removeEventListener("submit", this.boundCreate)
    this.nameInput?.removeEventListener("input", this.boundClearError)
  }

  clearError() {
    if (this.errorMessage) this.errorMessage.textContent = ""
  }

  reveal(event) {
    event.preventDefault()
    event.stopPropagation()
    this.clearError()
    if (!this.createForm.hidden) {
      this.createForm.hidden = true
      return
    }

    this.createForm.hidden = false
    this.nameInput?.focus()
  }

  async create(event) {
    event.preventDefault()
    event.stopPropagation()
    if (this.createForm.dataset.pending === "true") return

    const name = this.nameInput.value.trim()
    if (name === "") {
      this.errorMessage.textContent = "Name can't be blank."
      return
    }

    this.createForm.dataset.pending = "true"
    this.clearError()
    const token = document.querySelector("meta[name='csrf-token']")?.content
    try {
      const response = await fetch(this.createForm.action, {
        method: "POST",
        body: new FormData(this.createForm),
        headers: {
          "Accept": "application/json",
          "X-CSRF-Token": token || "",
          "X-Lists-Menu": "1"
        },
        credentials: "same-origin"
      })
      const payload = await response.json().catch(() => ({}))
      if (!response.ok) {
        this.errorMessage.textContent = payload.error || "That didn't save. Try again."
        return
      }

      this.insertList(payload)
      this.nameInput.value = ""
      this.errorMessage.textContent = ""
      const key = this.createForm.querySelector("[name='idempotency_key']")
      if (key) key.value = crypto.randomUUID()
      this.createForm.hidden = true
    } finally {
      delete this.createForm.dataset.pending
    }
  }

  insertList(list) {
    const fragment = this.rowTarget.content.cloneNode(true)
    const form = fragment.querySelector("form")
    const button = fragment.querySelector("[role=menuitem]")
    const formId = `add-to-list-new-${list.id}`
    form.id = formId
    form.action = list.remove_url
    form.dataset.addUrl = list.add_url
    form.dataset.removeUrl = list.remove_url
    button.setAttribute("form", formId)
    button.querySelector("span").textContent = list.name
    const anchor = this.divider || this.revealButton
    anchor.parentElement.insertBefore(fragment, anchor)
    this.divider?.classList.remove("hidden")
  }

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
