# frozen_string_literal: true

require "open3"

require_relative "test_helper"

class AddToListMarkTest < Minitest::Test
  CONTROLLER = File.expand_path(
    "../app/javascript/recording_studio_lists/controllers/add_to_list_controller.js",
    __dir__
  )

  def test_toggle_hides_and_shows_the_same_check
    source = File.read(CONTROLLER)
    source = source.sub(/\Aimport .+\n+/, "")
    source = source.sub(
      "export default class extends Controller",
      "class Controller {}\nclass AddToListController extends Controller"
    )

    output, status = Open3.capture2e("node", "--input-type=module", "--eval", "#{source}\n#{HARNESS}")

    assert status.success?, output
    assert_equal "ok", output.strip
  end

  HARNESS = <<~'JS'
    class MarkNode {
      constructor(tag) {
        this.tag = tag
        this.attrs = {}
        this.children = []
        this.dataset = {}
        this.parent = null
        this._hidden = false
      }

      set hidden(value) {
        this._hidden = Boolean(value)
        if (this._hidden) this.attrs.hidden = ""
        else delete this.attrs.hidden
      }

      get hidden() {
        return this._hidden
      }

      set type(value) { this.attrs.type = value }
      set name(value) { this.attrs.name = value }
      set value(value) { this.attrs.value = value }
      get value() { return this.attrs.value }

      setAttribute(name, value) {
        this.attrs[name] = value
        if (name === "hidden") this._hidden = true
      }

      removeAttribute(name) {
        delete this.attrs[name]
        if (name === "hidden") this._hidden = false
      }

      getAttribute(name) { return this.attrs[name] }

      querySelector(selector) {
        const match = selector.match(/^\[([^=]+)='([^']*)'\]$/)
        if (!match) throw new Error(`selector ${selector}`)
        const name = match[1]
        const expected = match[2]
        for (const child of this.children) {
          if (child.attrs[name] === expected) return child
          const found = child.querySelector(selector)
          if (found) return found
        }
        return null
      }

      remove() {
        if (!this.parent) return
        this.parent.children = this.parent.children.filter((child) => child !== this)
        this.parent = null
      }

      prepend(child) {
        child.parent = this
        this.children.unshift(child)
      }
    }

    globalThis.document = {
      createElement(tag) {
        return new MarkNode(tag)
      }
    }

    function markNode(tag, attrs = {}) {
      const node = new MarkNode(tag)
      node.attrs = { ...attrs }
      node._hidden = Object.hasOwn(attrs, "hidden")
      return node
    }

    const mark = markNode("svg", {
      "data-recording-studio-lists--add-to-list-target": "check"
    })
    const method = markNode("input", { name: "_method", value: "delete" })
    const form = markNode("form", { action: "/lists/1/items/2" })
    form.dataset = { addUrl: "/lists/1/items", removeUrl: "/lists/1/items/2" }
    form.prepend(method)
    const item = markNode("button")
    item.prepend(mark)

    const controller = new AddToListController()
    controller.flip(item, form)
    if (mark.getAttribute("hidden") !== "") throw new Error("unchecked rows hide the check")
    if (form.getAttribute("action") !== "/lists/1/items") throw new Error("add url")
    if (form.querySelector("[name='_method']")) throw new Error("delete method should be gone")

    controller.flip(item, form)
    if (mark.getAttribute("hidden") !== undefined) throw new Error("checked rows show the check")
    if (form.getAttribute("action") !== "/lists/1/items/2") throw new Error("remove url")
    const restored = form.querySelector("[name='_method']")
    if (!restored || restored.value !== "delete") throw new Error("delete method")
    if (item.querySelector("[data-recording-studio-lists--add-to-list-target='check']") !== mark) {
      throw new Error("the same check icon stays in the row")
    }
    console.log("ok")
  JS
end
