import { Controller } from "@hotwired/stimulus"

const ACCEPTED_TYPES = [
  "application/pdf",
  "image/jpeg",
  "image/png",
  "application/msword",
  "application/vnd.openxmlformats-officedocument.wordprocessingml.document"
]

const ACCEPTED_EXTENSIONS = [".pdf", ".jpg", ".jpeg", ".png", ".doc", ".docx"]

export default class extends Controller {
  static targets = ["input", "preview", "name", "info", "remove"]

  browse(event) {
    event.preventDefault()
    this.inputTarget.click()
  }

  ignore(event) {
    event.preventDefault()
  }

  dragover(event) {
    event.preventDefault()
    this.element.querySelector(".sign-dropzone")?.classList.add("is-dragover")
  }

  dragleave(event) {
    event.preventDefault()
    this.element.querySelector(".sign-dropzone")?.classList.remove("is-dragover")
  }

  drop(event) {
    event.preventDefault()
    this.element.querySelector(".sign-dropzone")?.classList.remove("is-dragover")

    const file = event.dataTransfer?.files?.[0]
    if (!file) return
    if (!this.accepted(file)) return

    this.assignFile(file)
  }

  change() {
    const file = this.inputTarget.files?.[0]
    if (!file) {
      this.clearPreview()
      return
    }

    this.showFile(file)
  }

  remove(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.clearPreview()
  }

  assignFile(file) {
    const transfer = new DataTransfer()
    transfer.items.add(file)
    this.inputTarget.files = transfer.files
    this.showFile(file)
  }

  showFile(file) {
    this.nameTarget.textContent = file.name
    this.infoTarget.textContent = `Selected · ${this.humanSize(file.size)}`
    this.removeTarget.setAttribute("aria-label", `Remove ${file.name}`)
    this.previewTarget.hidden = false
  }

  clearPreview() {
    this.nameTarget.textContent = ""
    this.infoTarget.textContent = ""
    this.previewTarget.hidden = true
  }

  accepted(file) {
    const name = file.name.toLowerCase()
    return ACCEPTED_TYPES.includes(file.type) || ACCEPTED_EXTENSIONS.some((ext) => name.endsWith(ext))
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }
}
