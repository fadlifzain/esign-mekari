import { Controller } from "@hotwired/stimulus"

export default class extends Controller {
  static targets = [
    "list",
    "template",
    "signer",
    "totalSignatures",
    "unitPrice",
    "totalCharge"
  ]

  static values = {
    price: { type: Number, default: 5000 },
    signers: { type: Array, default: [] }
  }

  connect() {
    if (!this.signersValue.length) {
      this.signersValue = [{ name: "", email: "", count: 1 }]
    }
    this.render()
  }

  addSigner() {
    this.signersValue = [...this.signersValue, { name: "", email: "", count: 1 }]
    this.render()
  }

  remove(event) {
    const index = this.indexFromEvent(event)
    const next = this.signersValue.filter((_, i) => i !== index)
    this.signersValue = next.length ? next : [{ name: "", email: "", count: 1 }]
    this.render()
  }

  increment(event) {
    this.patchCount(this.indexFromEvent(event), (count) => Math.min(20, count + 1))
  }

  decrement(event) {
    this.patchCount(this.indexFromEvent(event), (count) => Math.max(1, count - 1))
  }

  update(event) {
    const index = this.indexFromEvent(event)
    const field = event.target.dataset.field
    const signers = this.signersValue.map((signer, i) => {
      if (i !== index) return signer

      if (field === "count") {
        const value = Math.max(1, Math.min(20, parseInt(event.target.value, 10) || 1))
        return { ...signer, count: value }
      }

      return { ...signer, [field]: event.target.value }
    })

    this.signersValue = signers
    this.refreshSummary()
    this.refreshRowCharges()
  }

  patchCount(index, transform) {
    this.signersValue = this.signersValue.map((signer, i) => {
      if (i !== index) return signer
      return { ...signer, count: transform(signer.count || 1) }
    })
    this.render()
  }

  render() {
    this.listTarget.innerHTML = ""

    this.signersValue.forEach((signer, index) => {
      const node = this.templateTarget.content.firstElementChild.cloneNode(true)
      const nameInput = node.querySelector('[data-field="name"]')
      const emailInput = node.querySelector('[data-field="email"]')
      const countInput = node.querySelector('[data-field="count"]')

      nameInput.id = `signer-name-${index}`
      emailInput.id = `signer-email-${index}`
      countInput.id = `signer-count-${index}`
      node.querySelector("[data-name-label]").setAttribute("for", nameInput.id)
      node.querySelector("[data-email-label]").setAttribute("for", emailInput.id)
      node.querySelector("[data-count-label]").setAttribute("for", countInput.id)

      nameInput.value = signer.name || ""
      emailInput.value = signer.email || ""
      countInput.value = signer.count || 1
      node.querySelector('[data-field="subtotal"]').textContent = this.money((signer.count || 1) * this.priceValue)

      const name = signer.name || `signer ${index + 1}`
      node.querySelector('[data-action="recipients#decrement"]').setAttribute("aria-label", `Fewer signatures for ${name}`)
      node.querySelector('[data-action="recipients#increment"]').setAttribute("aria-label", `More signatures for ${name}`)
      node.querySelector('[data-action="recipients#remove"]').setAttribute("aria-label", `Remove ${name}`)

      this.listTarget.appendChild(node)
    })

    this.refreshSummary()
  }

  refreshRowCharges() {
    this.signerTargets.forEach((row, index) => {
      const signer = this.signersValue[index]
      if (!signer) return
      row.querySelector('[data-field="subtotal"]').textContent = this.money((signer.count || 1) * this.priceValue)
    })
  }

  refreshSummary() {
    const totalSignatures = this.signersValue.reduce((sum, signer) => sum + (signer.count || 0), 0)
    this.totalSignaturesTarget.textContent = totalSignatures
    this.unitPriceTarget.textContent = this.money(this.priceValue)
    this.totalChargeTarget.textContent = this.money(totalSignatures * this.priceValue)
  }

  indexFromEvent(event) {
    const row = event.target.closest("[data-recipients-target='signer']")
    return this.signerTargets.indexOf(row)
  }

  money(amount) {
    return `Rp ${Number(amount || 0).toLocaleString("id-ID")}`
  }
}
