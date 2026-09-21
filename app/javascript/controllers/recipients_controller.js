import { Controller } from "@hotwired/stimulus"
import {
  clampMeteraiCount,
  clampSignatureCount,
  clampStep,
  deriveTotals,
  displayMoney,
  hasErrors,
  recipientChargeCents,
  SIGNATURE_PRICE_CENTS,
  SIGNATURE_QUOTA,
  METERAI_PRICE_CENTS,
  validateState
} from "sign/recipients"

export default class extends Controller {
  static targets = [
    "list",
    "template",
    "signer",
    "signatureLine",
    "meteraiLine",
    "totalCharge",
    "signatureQuota",
    "meteraiQuota",
    "continue",
    "banner",
    "add"
  ]

  static values = {
    signaturePriceCents: { type: Number, default: SIGNATURE_PRICE_CENTS },
    meteraiPriceCents: { type: Number, default: METERAI_PRICE_CENTS },
    signers: { type: Array, default: [] },
    orderMode: { type: String, default: "parallel" },
    envelopeId: { type: String, default: "" }
  }

  connect() {
    if (!this.signersValue.length) {
      this.signersValue = [this.blankSigner()]
    }
    this.previewGeneration = 0
    this.render()
  }

  setOrderMode(event) {
    this.orderModeValue = event.currentTarget.dataset.mode
    this.render()
  }

  addSigner() {
    if (this.signersValue.length >= SIGNATURE_QUOTA) return
    this.signersValue = [...this.signersValue, this.blankSigner()]
    this.render()
  }

  remove(event) {
    const index = this.indexFromEvent(event)
    const next = this.signersValue.filter((_, i) => i !== index)
    this.signersValue = next.length ? next : [this.blankSigner()]
    this.render()
  }

  incrementSignature(event) {
    this.patch(this.indexFromEvent(event), (signer) => this.withSignatureCount(signer, signer.signature_count + 1))
  }

  decrementSignature(event) {
    this.patch(this.indexFromEvent(event), (signer) => this.withSignatureCount(signer, signer.signature_count - 1))
  }

  incrementMeterai(event) {
    this.patch(this.indexFromEvent(event), (signer) => ({
      ...signer,
      meterai_count: clampMeteraiCount(signer.meterai_count + 1, signer.signature_count)
    }))
  }

  decrementMeterai(event) {
    this.patch(this.indexFromEvent(event), (signer) => ({
      ...signer,
      meterai_count: clampMeteraiCount(signer.meterai_count - 1, signer.signature_count)
    }))
  }

  incrementStep(event) {
    this.patch(this.indexFromEvent(event), (signer) => ({ ...signer, step: clampStep(signer.step + 1) }))
  }

  decrementStep(event) {
    this.patch(this.indexFromEvent(event), (signer) => ({ ...signer, step: clampStep(signer.step - 1) }))
  }

  update(event) {
    const index = this.indexFromEvent(event)
    const field = event.target.dataset.field
    this.signersValue = this.signersValue.map((signer, i) => {
      if (i !== index) return signer
      if (field === "signature_count") return this.withSignatureCount(signer, event.target.value)
      if (field === "meterai_count") {
        return { ...signer, meterai_count: clampMeteraiCount(event.target.value, signer.signature_count) }
      }
      if (field === "step") return { ...signer, step: clampStep(event.target.value) }
      return { ...signer, [field]: event.target.value }
    })
    this.refresh()
  }

  async continue(event) {
    event.preventDefault()
    const errors = validateState(this.signersValue, this.orderModeValue)
    if (hasErrors(errors)) {
      this.applyErrors(errors, "Fix the highlighted recipients before continuing.")
      return
    }

    if (!this.envelopeIdValue) {
      this.applyErrors(errors, "Upload a document first, then set recipients.")
      return
    }

    const generation = ++this.previewGeneration
    this.continueTarget.disabled = true
    this.continueTarget.textContent = "Checking…"

    try {
      const response = await fetch(`/api/envelopes/${this.envelopeIdValue}/charge-preview`, {
        method: "POST",
        headers: {
          "Content-Type": "application/json",
          Accept: "application/json",
          "X-CSRF-Token": document.querySelector('meta[name="csrf-token"]')?.content || ""
        },
        body: JSON.stringify(this.payload())
      })
      const body = await response.json()
      if (generation !== this.previewGeneration) return

      if (!response.ok) {
        this.applyServerError(body)
        return
      }

      this.totalChargeTarget.textContent = displayMoney(this.centsFromApi(body.total_charge))
      this.clearBanner()
    } catch {
      if (generation !== this.previewGeneration) return
      this.showBanner("The charge preview failed. Your recipients are still here — try again.")
    } finally {
      if (generation === this.previewGeneration) {
        this.continueTarget.textContent = "Continue"
        this.refresh()
      }
    }
  }

  withSignatureCount(signer, raw) {
    const signature_count = clampSignatureCount(raw)
    return {
      ...signer,
      signature_count,
      meterai_count: clampMeteraiCount(signer.meterai_count, signature_count)
    }
  }

  patch(index, transform) {
    this.signersValue = this.signersValue.map((signer, i) => (i === index ? transform(signer) : signer))
    this.render()
  }

  render() {
    this.element.classList.toggle("is-sequential", this.orderModeValue === "sequential")
    this.element.querySelectorAll("[data-mode]").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.mode === this.orderModeValue)
      button.setAttribute("aria-pressed", button.dataset.mode === this.orderModeValue ? "true" : "false")
    })

    this.listTarget.innerHTML = ""
    this.signersValue.forEach((signer, index) => {
      const node = this.templateTarget.content.firstElementChild.cloneNode(true)
      this.bindRow(node, signer, index)
      this.listTarget.appendChild(node)
    })

    if (this.hasAddTarget) {
      this.addTarget.hidden = this.signersValue.length >= SIGNATURE_QUOTA
    }

    this.refresh()
  }

  bindRow(node, signer, index) {
    const nameInput = node.querySelector('[data-field="name"]')
    const emailInput = node.querySelector('[data-field="email"]')
    const signatureInput = node.querySelector('[data-field="signature_count"]')
    const meteraiInput = node.querySelector('[data-field="meterai_count"]')
    const stepInput = node.querySelector('[data-field="step"]')

    nameInput.id = `signer-name-${index}`
    emailInput.id = `signer-email-${index}`
    signatureInput.id = `signer-signature-${index}`
    meteraiInput.id = `signer-meterai-${index}`
    stepInput.id = `signer-step-${index}`

    node.querySelector("[data-name-label]").setAttribute("for", nameInput.id)
    node.querySelector("[data-email-label]").setAttribute("for", emailInput.id)
    node.querySelector("[data-signature-label]").setAttribute("for", signatureInput.id)
    node.querySelector("[data-meterai-label]").setAttribute("for", meteraiInput.id)
    node.querySelector("[data-step-label]").setAttribute("for", stepInput.id)

    nameInput.value = signer.name || ""
    emailInput.value = signer.email || ""
    signatureInput.value = signer.signature_count
    meteraiInput.value = signer.meterai_count
    stepInput.value = signer.step || 1
    node.querySelector('[data-field="subtotal"]').textContent = displayMoney(recipientChargeCents(signer))

    const name = signer.name || `recipient ${index + 1}`
    node.querySelector('[data-action="recipients#decrementSignature"]').setAttribute("aria-label", `Fewer signatures for ${name}`)
    node.querySelector('[data-action="recipients#incrementSignature"]').setAttribute("aria-label", `More signatures for ${name}`)
    node.querySelector('[data-action="recipients#decrementMeterai"]').setAttribute("aria-label", `Fewer eMeterai for ${name}`)
    node.querySelector('[data-action="recipients#incrementMeterai"]').setAttribute("aria-label", `More eMeterai for ${name}`)
    node.querySelector('[data-action="recipients#decrementStep"]').setAttribute("aria-label", `Earlier step for ${name}`)
    node.querySelector('[data-action="recipients#incrementStep"]').setAttribute("aria-label", `Later step for ${name}`)
    node.querySelector('[data-action="recipients#remove"]').setAttribute("aria-label", `Remove ${name}`)
  }

  refresh() {
    const totals = deriveTotals(this.signersValue)
    this.signatureLineTarget.textContent = `${totals.totalSignatures} signatures × ${displayMoney(this.signaturePriceCentsValue)}`
    this.meteraiLineTarget.textContent = `${totals.totalMeterai} eMeterai × ${displayMoney(this.meteraiPriceCentsValue)}`
    this.totalChargeTarget.textContent = displayMoney(totals.totalChargeCents)
    this.signatureQuotaTarget.textContent = `Signature ${totals.signatureQuotaUsed}`
    this.meteraiQuotaTarget.textContent = `eMeterai ${totals.meteraiQuotaUsed}`

    this.signerTargets.forEach((row, index) => {
      const signer = this.signersValue[index]
      if (!signer) return
      row.querySelector('[data-field="subtotal"]').textContent = displayMoney(recipientChargeCents(signer))
      const signatureInput = row.querySelector('[data-field="signature_count"]')
      const meteraiInput = row.querySelector('[data-field="meterai_count"]')
      if (document.activeElement !== signatureInput) signatureInput.value = signer.signature_count
      if (document.activeElement !== meteraiInput) meteraiInput.value = signer.meterai_count
    })

    const errors = validateState(this.signersValue, this.orderModeValue)
    this.applyErrors(errors)
  }

  applyErrors(errors, bannerMessage) {
    this.signerTargets.forEach((row, index) => {
      const messages = errors.rows[index] || []
      row.classList.toggle("is-invalid", messages.length > 0)
      const output = row.querySelector('[data-field="row-error"]')
      output.hidden = messages.length === 0
      output.textContent = messages[0] || ""
    })

    const blocking = hasErrors(errors) || !this.envelopeIdValue
    if (this.hasContinueTarget) this.continueTarget.disabled = blocking

    if (bannerMessage) {
      this.showBanner(bannerMessage)
    } else if (errors.global.length) {
      this.showBanner(errors.global[0])
    } else if (!this.envelopeIdValue) {
      this.showBanner("Upload a document first, then set recipients.")
    } else {
      this.clearBanner()
    }
  }

  applyServerError(body) {
    const error = body?.error || {}
    const message = error.message || "The charge preview was rejected."
    if (error.recipient_email) {
      const index = this.signersValue.findIndex((signer) => signer.email.trim().toLowerCase() === error.recipient_email.trim().toLowerCase())
      if (index >= 0) {
        const errors = validateState(this.signersValue, this.orderModeValue)
        errors.rows[index] = [message, ...errors.rows[index]]
        this.applyErrors(errors, message)
        return
      }
    }
    this.showBanner(message)
    if (this.hasContinueTarget) this.continueTarget.disabled = false
  }

  payload() {
    return {
      order_mode: this.orderModeValue,
      recipients: this.signersValue.map((signer) => {
        const row = {
          name: signer.name,
          email: signer.email,
          signature_count: signer.signature_count,
          meterai_count: signer.meterai_count
        }
        if (this.orderModeValue === "sequential") row.step = signer.step
        return row
      })
    }
  }

  centsFromApi(value) {
    const [whole, fraction = "00"] = String(value).split(".")
    return Number.parseInt(whole, 10) * 100 + Number.parseInt(fraction.padEnd(2, "0").slice(0, 2), 10)
  }

  showBanner(message) {
    if (!this.hasBannerTarget) return
    this.bannerTarget.hidden = false
    this.bannerTarget.textContent = message
  }

  clearBanner() {
    if (!this.hasBannerTarget) return
    this.bannerTarget.hidden = true
    this.bannerTarget.textContent = ""
  }

  blankSigner() {
    return { name: "", email: "", signature_count: 1, meterai_count: 0, step: 1 }
  }

  indexFromEvent(event) {
    const row = event.target.closest("[data-recipients-target='signer']")
    return this.signerTargets.indexOf(row)
  }
}
