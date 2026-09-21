import { Controller } from "@hotwired/stimulus"
import {
  canMergeRecipient,
  canMoveRecipient,
  clampMeteraiCount,
  clampSignatureCount,
  deriveTotals,
  displayMoney,
  groupByStep,
  hasErrors,
  mergeRecipient,
  moveRecipient,
  recipientChargeCents,
  renormalizeSteps,
  SIGNATURE_PRICE_CENTS,
  SIGNATURE_QUOTA,
  METERAI_PRICE_CENTS,
  validateState
} from "sign/recipients"

const PARALLEL_COPY = "Everyone below is invited at the same time. Fields are placed manually in the next step."
const SEQUENTIAL_COPY = "The next step is invited only after everyone in the previous step has finished. Recipients who share a step sign in parallel."

export default class extends Controller {
  static targets = [
    "list",
    "template",
    "stepGroup",
    "signer",
    "signatureLine",
    "meteraiLine",
    "totalCharge",
    "signatureQuota",
    "meteraiQuota",
    "continue",
    "banner",
    "add",
    "subtitle"
  ]

  static values = {
    signaturePriceCents: { type: Number, default: SIGNATURE_PRICE_CENTS },
    meteraiPriceCents: { type: Number, default: METERAI_PRICE_CENTS },
    signers: { type: Array, default: [] },
    orderMode: { type: String, default: "parallel" },
    envelopeId: { type: String, default: "" }
  }

  connect() {
    this.signerSeq = 0
    this.previewGeneration = 0
    const seed = this.signersValue.length ? this.signersValue : [this.blankSigner()]
    this.signersValue = this.withIds(seed)
    this.render()
  }

  setOrderMode(event) {
    this.orderModeValue = event.currentTarget.dataset.mode
    if (this.orderModeValue === "sequential") {
      this.signersValue = renormalizeSteps(this.signersValue)
    }
    this.render()
  }

  addSigner() {
    if (this.signersValue.length >= SIGNATURE_QUOTA) return
    const signer = this.blankSigner()
    if (this.orderModeValue === "sequential") {
      const maxStep = this.signersValue.reduce((max, row) => Math.max(max, row.step || 1), 0)
      signer.step = maxStep + 1
    }
    this.signersValue = [...this.signersValue, signer]
    this.render()
  }

  remove(event) {
    const id = this.idFromEvent(event)
    const next = this.signersValue.filter((signer) => signer.id !== id)
    const remaining = next.length ? next : [this.blankSigner()]
    this.signersValue = this.orderModeValue === "sequential" ? renormalizeSteps(remaining) : remaining
    this.render()
  }

  moveUp(event) {
    this.reorder(event, (signers, id) => moveRecipient(signers, id, "up"))
  }

  moveDown(event) {
    this.reorder(event, (signers, id) => moveRecipient(signers, id, "down"))
  }

  mergePrevious(event) {
    this.reorder(event, (signers, id) => mergeRecipient(signers, id, "previous"))
  }

  mergeNext(event) {
    this.reorder(event, (signers, id) => mergeRecipient(signers, id, "next"))
  }

  reorder(event, transform) {
    const id = this.idFromEvent(event)
    this.signersValue = transform(this.signersValue, id)
    this.render()
  }

  incrementSignature(event) {
    this.patch(this.idFromEvent(event), (signer) => this.withSignatureCount(signer, signer.signature_count + 1))
  }

  decrementSignature(event) {
    this.patch(this.idFromEvent(event), (signer) => this.withSignatureCount(signer, signer.signature_count - 1))
  }

  incrementMeterai(event) {
    this.patch(this.idFromEvent(event), (signer) => ({
      ...signer,
      meterai_count: clampMeteraiCount(signer.meterai_count + 1, signer.signature_count)
    }))
  }

  decrementMeterai(event) {
    this.patch(this.idFromEvent(event), (signer) => ({
      ...signer,
      meterai_count: clampMeteraiCount(signer.meterai_count - 1, signer.signature_count)
    }))
  }

  update(event) {
    const id = this.idFromEvent(event)
    const field = event.target.dataset.field
    this.signersValue = this.signersValue.map((signer) => {
      if (signer.id !== id) return signer
      if (field === "signature_count") return this.withSignatureCount(signer, event.target.value)
      if (field === "meterai_count") {
        return { ...signer, meterai_count: clampMeteraiCount(event.target.value, signer.signature_count) }
      }
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

  patch(id, transform) {
    this.signersValue = this.signersValue.map((signer) => (signer.id === id ? transform(signer) : signer))
    this.render()
  }

  render() {
    const focus = this.captureFocus()
    const sequential = this.orderModeValue === "sequential"
    this.element.classList.toggle("is-sequential", sequential)
    this.element.querySelectorAll("[data-mode]").forEach((button) => {
      button.classList.toggle("is-active", button.dataset.mode === this.orderModeValue)
      button.setAttribute("aria-pressed", button.dataset.mode === this.orderModeValue ? "true" : "false")
    })
    if (this.hasSubtitleTarget) {
      this.subtitleTarget.textContent = sequential ? SEQUENTIAL_COPY : PARALLEL_COPY
    }

    this.listTarget.innerHTML = ""
    if (sequential) {
      groupByStep(this.signersValue).forEach((group, groupIndex, groups) => {
        const section = this.stepGroupTarget.content.firstElementChild.cloneNode(true)
        this.bindStepGroup(section, group, groupIndex, groups.length)
        group.recipients.forEach((signer) => {
          section.querySelector("[data-step-members]").appendChild(this.buildRow(signer, group))
        })
        this.listTarget.appendChild(section)
      })
    } else {
      this.signersValue.forEach((signer) => this.listTarget.appendChild(this.buildRow(signer)))
    }

    if (this.hasAddTarget) {
      this.addTarget.hidden = this.signersValue.length >= SIGNATURE_QUOTA
    }

    this.refresh()
    this.restoreFocus(focus)
  }

  bindStepGroup(section, group, groupIndex, totalGroups) {
    const title = section.querySelector("[data-step-title]")
    const hint = section.querySelector("[data-step-hint]")
    const parallel = section.querySelector("[data-step-parallel]")
    title.textContent = `Step ${group.step}`
    hint.textContent = groupIndex === 0
      ? "Invited immediately."
      : `Invited after step ${group.step - 1} is complete.`
    if (group.recipients.length > 1) {
      parallel.hidden = false
      parallel.textContent = `${group.recipients.length} recipients sign in parallel`
    } else {
      parallel.hidden = true
      parallel.textContent = ""
    }
    section.setAttribute("aria-label", `Signing step ${group.step} of ${totalGroups}`)
  }

  buildRow(signer, group) {
    const node = this.templateTarget.content.firstElementChild.cloneNode(true)
    this.bindRow(node, signer, group)
    return node
  }

  bindRow(node, signer, group) {
    const index = this.signersValue.findIndex((row) => row.id === signer.id)
    const nameInput = node.querySelector('[data-field="name"]')
    const emailInput = node.querySelector('[data-field="email"]')
    const signatureInput = node.querySelector('[data-field="signature_count"]')
    const meteraiInput = node.querySelector('[data-field="meterai_count"]')

    node.dataset.signerId = signer.id
    node.classList.toggle("is-parallel", Boolean(group && group.recipients.length > 1))

    nameInput.id = `signer-name-${signer.id}`
    emailInput.id = `signer-email-${signer.id}`
    signatureInput.id = `signer-signature-${signer.id}`
    meteraiInput.id = `signer-meterai-${signer.id}`

    node.querySelector("[data-name-label]").setAttribute("for", nameInput.id)
    node.querySelector("[data-email-label]").setAttribute("for", emailInput.id)
    node.querySelector("[data-signature-label]").setAttribute("for", signatureInput.id)
    node.querySelector("[data-meterai-label]").setAttribute("for", meteraiInput.id)

    nameInput.value = signer.name || ""
    emailInput.value = signer.email || ""
    signatureInput.value = signer.signature_count
    meteraiInput.value = signer.meterai_count
    node.querySelector('[data-field="subtotal"]').textContent = displayMoney(recipientChargeCents(signer))

    const name = signer.name?.trim() || `recipient ${index + 1}`
    this.setAria(node, "recipients#decrementSignature", `Fewer signatures for ${name}`)
    this.setAria(node, "recipients#incrementSignature", `More signatures for ${name}`)
    this.setAria(node, "recipients#decrementMeterai", `Fewer eMeterai for ${name}`)
    this.setAria(node, "recipients#incrementMeterai", `More eMeterai for ${name}`)
    this.setAria(node, "recipients#remove", `Remove ${name}`)
    this.bindReorder(node, signer, name)
  }

  bindReorder(node, signer, name) {
    const moveUp = node.querySelector('[data-action="recipients#moveUp"]')
    const moveDown = node.querySelector('[data-action="recipients#moveDown"]')
    const mergePrevious = node.querySelector('[data-action="recipients#mergePrevious"]')
    const mergeNext = node.querySelector('[data-action="recipients#mergeNext"]')
    if (!moveUp) return

    moveUp.setAttribute("aria-label", `Move ${name} earlier`)
    moveDown.setAttribute("aria-label", `Move ${name} later`)
    mergePrevious.setAttribute("aria-label", `Merge ${name} into previous step`)
    mergeNext.setAttribute("aria-label", `Merge ${name} into next step`)

    moveUp.disabled = !canMoveRecipient(this.signersValue, signer.id, "up")
    moveDown.disabled = !canMoveRecipient(this.signersValue, signer.id, "down")
    mergePrevious.disabled = !canMergeRecipient(this.signersValue, signer.id, "previous")
    mergeNext.disabled = !canMergeRecipient(this.signersValue, signer.id, "next")
  }

  setAria(node, action, label) {
    const button = node.querySelector(`[data-action="${action}"]`)
    if (button) button.setAttribute("aria-label", label)
  }

  refresh() {
    const totals = deriveTotals(this.signersValue)
    this.signatureLineTarget.textContent = `${totals.totalSignatures} signatures × ${displayMoney(this.signaturePriceCentsValue)}`
    this.meteraiLineTarget.textContent = `${totals.totalMeterai} eMeterai × ${displayMoney(this.meteraiPriceCentsValue)}`
    this.totalChargeTarget.textContent = displayMoney(totals.totalChargeCents)
    this.signatureQuotaTarget.textContent = `Signature ${totals.signatureQuotaUsed}`
    this.meteraiQuotaTarget.textContent = `eMeterai ${totals.meteraiQuotaUsed}`

    this.signerTargets.forEach((row) => {
      const signer = this.signerFromRow(row)
      if (!signer) return
      row.querySelector('[data-field="subtotal"]').textContent = displayMoney(recipientChargeCents(signer))
      const signatureInput = row.querySelector('[data-field="signature_count"]')
      const meteraiInput = row.querySelector('[data-field="meterai_count"]')
      if (document.activeElement !== signatureInput) signatureInput.value = signer.signature_count
      if (document.activeElement !== meteraiInput) meteraiInput.value = signer.meterai_count

      const index = this.signersValue.findIndex((rowSigner) => rowSigner.id === signer.id)
      const name = signer.name?.trim() || `recipient ${index + 1}`
      this.setAria(row, "recipients#decrementSignature", `Fewer signatures for ${name}`)
      this.setAria(row, "recipients#incrementSignature", `More signatures for ${name}`)
      this.setAria(row, "recipients#decrementMeterai", `Fewer eMeterai for ${name}`)
      this.setAria(row, "recipients#incrementMeterai", `More eMeterai for ${name}`)
      this.setAria(row, "recipients#remove", `Remove ${name}`)
      this.bindReorder(row, signer, name)
    })

    const errors = validateState(this.signersValue, this.orderModeValue)
    this.applyErrors(errors)
  }

  applyErrors(errors, bannerMessage) {
    this.signerTargets.forEach((row) => {
      const index = this.signersValue.findIndex((signer) => signer.id === row.dataset.signerId)
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
    return { id: this.nextSignerId(), name: "", email: "", signature_count: 1, meterai_count: 0, step: 1 }
  }

  withIds(signers) {
    return signers.map((signer) => (signer.id ? signer : { ...signer, id: this.nextSignerId() }))
  }

  nextSignerId() {
    this.signerSeq = (this.signerSeq || 0) + 1
    return `signer-${this.signerSeq}`
  }

  idFromEvent(event) {
    return event.target.closest("[data-signer-id]")?.dataset.signerId
  }

  signerFromRow(row) {
    return this.signersValue.find((signer) => signer.id === row.dataset.signerId)
  }

  captureFocus() {
    const active = document.activeElement
    if (!active || !this.element.contains(active)) return null
    const row = active.closest("[data-signer-id]")
    return {
      signerId: row?.dataset.signerId,
      action: active.dataset.action,
      field: active.dataset.field,
      mode: active.dataset.mode,
      selectionStart: active.selectionStart,
      selectionEnd: active.selectionEnd
    }
  }

  restoreFocus(focus) {
    if (!focus) return
    if (focus.mode) {
      this.element.querySelector(`[data-mode="${focus.mode}"]`)?.focus()
      return
    }
    if (!focus.signerId) return

    const row = this.listTarget.querySelector(`[data-signer-id="${focus.signerId}"]`)
    if (!row) return

    const byAction = focus.action ? row.querySelector(`[data-action="${focus.action}"]`) : null
    const byField = focus.field ? row.querySelector(`[data-field="${focus.field}"]`) : null
    const fallback = [...row.querySelectorAll("button, input")].find((node) => !node.disabled)
    const el = (byAction && !byAction.disabled && byAction) || byField || fallback
    if (!el) return

    el.focus()
    if (typeof focus.selectionStart === "number" && typeof el.setSelectionRange === "function") {
      try {
        el.setSelectionRange(focus.selectionStart, focus.selectionEnd)
      } catch {
        // number inputs may reject setSelectionRange
      }
    }
  }
}
