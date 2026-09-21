import assert from "node:assert/strict"
import { test } from "node:test"
import { clampField, fieldInBounds } from "../../app/javascript/sign/fields.js"
import { formatApi, formatDisplay } from "../../app/javascript/sign/money.js"
import {
  clampMeteraiCount,
  clampSignatureCount,
  deriveTotals,
  hasErrors,
  recipientChargeCents,
  validateState
} from "../../app/javascript/sign/recipients.js"

const rina = { name: "Rina Halim", email: "rina.halim@example.test", signature_count: 2, meterai_count: 1, step: 1 }
const budi = { name: "Budi Santoso", email: "budi.santoso@example.test", signature_count: 1, meterai_count: 0, step: 2 }

test("derived totals keep signatures and eMeterai on separate lines", () => {
  const totals = deriveTotals([rina, budi])
  assert.equal(totals.totalSignatures, 3)
  assert.equal(totals.totalMeterai, 1)
  assert.equal(formatApi(totals.signatureChargeCents), "15000.00")
  assert.equal(formatApi(totals.meteraiChargeCents), "10000.25")
  assert.equal(formatApi(totals.totalChargeCents), "25000.25")
  assert.equal(formatDisplay(totals.signatureChargeCents), "Rp15.000,00")
  assert.equal(formatDisplay(totals.meteraiChargeCents), "Rp10.000,25")
  assert.equal(totals.signatureQuotaUsed, "2/8")
  assert.equal(totals.meteraiQuotaUsed, "1/3")
})

test("per-row charge is the combined derived cost", () => {
  assert.equal(formatDisplay(recipientChargeCents(rina)), "Rp20.000,25")
  assert.equal(formatDisplay(recipientChargeCents(budi)), "Rp5.000,00")
})

test("meterai count is clamped to 0-3 and never above signatures", () => {
  assert.equal(clampMeteraiCount("abc", 2), 0)
  assert.equal(clampMeteraiCount(-1, 2), 0)
  assert.equal(clampMeteraiCount(4, 2), 2)
  assert.equal(clampMeteraiCount(3, 1), 1)
  assert.equal(clampSignatureCount("abc"), 1)
  assert.equal(clampSignatureCount(0), 1)
  assert.equal(clampSignatureCount(21), 20)
})

test("sequential meterai outside step 1 is a row error naming the rule", () => {
  const errors = validateState([
    { ...rina, meterai_count: 0, step: 1 },
    { ...budi, meterai_count: 1, step: 2 }
  ], "sequential")

  assert.equal(hasErrors(errors), true)
  assert.match(errors.rows[1][0], /step 1/)
  assert.equal(errors.rows[0].length, 0)
})

test("parallel mode does not apply the first-step stamp rule", () => {
  const errors = validateState([
    { ...rina, step: 2 },
    { ...budi, step: 2 }
  ], "parallel")

  assert.equal(errors.rows.every((row) => row.length === 0), true)
})

test("quota messages distinguish recipient rows from eMeterai stamps", () => {
  const rows = Array.from({ length: 9 }, (_, index) => ({
    name: `Signer ${index + 1}`,
    email: `signer${index + 1}@example.test`,
    signature_count: 1,
    meterai_count: 0,
    step: 1
  }))
  const signature = validateState(rows, "parallel")
  assert.match(signature.global[0], /signature quota/)
  assert.doesNotMatch(signature.global[0], /eMeterai quota/)

  const meterai = validateState([
    { name: "Rina Halim", email: "rina.halim@example.test", signature_count: 3, meterai_count: 3, step: 1 },
    { name: "Budi Santoso", email: "budi.santoso@example.test", signature_count: 1, meterai_count: 1, step: 1 }
  ], "parallel")
  assert.match(meterai.global[0], /eMeterai quota/)
  assert.doesNotMatch(meterai.global[0], /signature quota/)
})

test("many stamps on few rows do not consume signature quota", () => {
  const recipients = [
    { name: "Rina Halim", email: "rina.halim@example.test", signature_count: 20, meterai_count: 0, step: 1 },
    { name: "Budi Santoso", email: "budi.santoso@example.test", signature_count: 20, meterai_count: 0, step: 1 }
  ]
  const totals = deriveTotals(recipients)
  const errors = validateState(recipients, "parallel")

  assert.equal(totals.totalSignatures, 40)
  assert.equal(totals.signatureQuotaUsed, "2/8")
  assert.equal(errors.global.some((message) => /signature quota/.test(message)), false)
})

test("eight recipient rows with extra stamps fill quota without an error", () => {
  const recipients = Array.from({ length: 8 }, (_, index) => ({
    name: `Signer ${index + 1}`,
    email: `signer${index + 1}@example.test`,
    signature_count: 2,
    meterai_count: 0,
    step: 1
  }))
  const totals = deriveTotals(recipients)
  const errors = validateState(recipients, "parallel")

  assert.equal(totals.totalSignatures, 16)
  assert.equal(totals.signatureQuotaUsed, "8/8")
  assert.equal(errors.global.some((message) => /signature quota/.test(message)), false)
})

test("UI clamps field coordinates while out-of-range stays invalid for the API", () => {
  assert.deepEqual(clampField("signature", 500, 800), { x: 420, y: 500 })
  assert.deepEqual(clampField("meterai", -10, 900), { x: 0, y: 476 })
  assert.equal(fieldInBounds("signature", 421, 0), false)
  assert.equal(fieldInBounds("meterai", 0, 477), false)
  assert.equal(fieldInBounds("signature", 420, 500), true)
  assert.equal(fieldInBounds("meterai", 520, 476), true)
})
