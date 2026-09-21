import { Controller } from "@hotwired/stimulus"

const ACCEPTED_EXTENSIONS = ["pdf", "jpg", "jpeg", "png", "doc", "docx"]

export default class extends Controller {
  static targets = ["input", "preview", "name", "info", "remove", "continue", "error"]

  browse(event) {
    event.preventDefault()
    this.inputTarget.click()
  }

  ignore(event) {
    event.preventDefault()
  }

  guardContinue(event) {
    if (this.continueTarget.classList.contains("is-disabled")) event.preventDefault()
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
    if (file) this.upload(file)
  }

  change() {
    const file = this.inputTarget.files?.[0]
    if (!file) {
      this.clearPreview()
      return
    }
    this.upload(file)
  }

  remove(event) {
    event.preventDefault()
    this.inputTarget.value = ""
    this.clearPreview()
  }

  async upload(file) {
    const frontendError = this.clientError(file)
    if (frontendError) {
      this.showError(frontendError)
      this.clearPreview()
      return
    }

    this.showError("")
    this.setContinue(false)
    this.nameTarget.textContent = file.name
    this.infoTarget.textContent = "Uploading…"
    this.removeTarget.setAttribute("aria-label", `Remove ${file.name}`)
    this.previewTarget.hidden = false

    const body = new FormData()
    body.append("file", file)

    try {
      const response = await fetch("/api/envelopes", {
        method: "POST",
        headers: {
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body
      })
      const payload = await this.readJson(response)
      if (!response.ok) {
        this.showError(payload.error?.message || "Upload failed")
        this.clearPreview()
        return
      }

      const documentMeta = payload.document
      this.nameTarget.textContent = documentMeta.filename
      this.infoTarget.textContent = `Uploaded · ${documentMeta.page_count} pages · ${this.humanSize(documentMeta.size_bytes)}`
      this.removeTarget.setAttribute("aria-label", `Remove ${documentMeta.filename}`)
      this.setContinue(true)
    } catch (error) {
      this.showError(error.message || "Upload failed. Try again without leaving this page.")
      this.setContinue(false)
    }
  }

  async readJson(response) {
    const text = await response.text()
    try {
      return JSON.parse(text)
    } catch {
      throw new Error("Upload failed. Try again without leaving this page.")
    }
  }

  clientError(file) {
    const filename = file.name || ""
    const extension = filename.split(".").pop()?.toLowerCase()
    if (!ACCEPTED_EXTENSIONS.includes(extension) || filename.toLowerCase().endsWith(".pdf.exe")) {
      return "File type is not supported"
    }
    if (file.size > 10 * 1024 * 1024) {
      return "File must be 10 MB or smaller"
    }
    return null
  }

  clearPreview() {
    this.nameTarget.textContent = ""
    this.infoTarget.textContent = ""
    this.previewTarget.hidden = true
    this.setContinue(false)
  }

  setContinue(enabled) {
    if (!this.hasContinueTarget) return
    this.continueTarget.classList.toggle("is-disabled", !enabled)
    this.continueTarget.setAttribute("aria-disabled", enabled ? "false" : "true")
    if (enabled) this.continueTarget.removeAttribute("tabindex")
    else this.continueTarget.setAttribute("tabindex", "-1")
  }

  showError(message) {
    let node = this.element.querySelector("[data-upload-error]")
    if (!node) {
      node = document.createElement("p")
      node.className = "sign-banner"
      node.dataset.uploadError = "true"
      this.element.querySelector(".sign-body")?.prepend(node)
    }
    node.hidden = !message
    node.textContent = message
  }

  humanSize(bytes) {
    if (bytes < 1024) return `${bytes} B`
    if (bytes < 1024 * 1024) return `${(bytes / 1024).toFixed(1)} KB`
    return `${(bytes / (1024 * 1024)).toFixed(1)} MB`
  }
}
