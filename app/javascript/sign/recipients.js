import {
  SIGNATURE_PRICE_CENTS,
  METERAI_PRICE_CENTS,
  SIGNATURE_QUOTA,
  METERAI_QUOTA,
  MAX_RECIPIENTS,
  SIGNATURE_MIN,
  SIGNATURE_MAX,
  METERAI_MIN,
  METERAI_MAX
} from "sign/config"
import { formatDisplay } from "sign/money"

export function parseInteger(raw, fallback) {
  if (typeof raw === "number" && Number.isInteger(raw)) return raw
  if (typeof raw === "string" && /^-?\d+$/.test(raw.trim())) {
    return Number.parseInt(raw.trim(), 10)
  }
  return fallback
}

export function clampSignatureCount(raw) {
  const value = parseInteger(raw, SIGNATURE_MIN)
  if (value < SIGNATURE_MIN) return SIGNATURE_MIN
  if (value > SIGNATURE_MAX) return SIGNATURE_MAX
  return value
}

export function clampMeteraiCount(raw, signatureCount) {
  const max = Math.min(METERAI_MAX, signatureCount)
  const value = parseInteger(raw, METERAI_MIN)
  if (value < METERAI_MIN) return METERAI_MIN
  if (value > max) return max
  return value
}

export function clampStep(raw) {
  const value = parseInteger(raw, 1)
  return value < 1 ? 1 : value
}

export function recipientChargeCents(recipient) {
  return recipient.signature_count * SIGNATURE_PRICE_CENTS + recipient.meterai_count * METERAI_PRICE_CENTS
}

export function deriveTotals(recipients) {
  const totalSignatures = recipients.reduce((sum, recipient) => sum + recipient.signature_count, 0)
  const totalMeterai = recipients.reduce((sum, recipient) => sum + recipient.meterai_count, 0)
  const signatureChargeCents = totalSignatures * SIGNATURE_PRICE_CENTS
  const meteraiChargeCents = totalMeterai * METERAI_PRICE_CENTS

  return {
    totalSignatures,
    totalMeterai,
    signatureChargeCents,
    meteraiChargeCents,
    totalChargeCents: signatureChargeCents + meteraiChargeCents,
    signatureQuotaUsed: `${recipients.length}/${SIGNATURE_QUOTA}`,
    meteraiQuotaUsed: `${totalMeterai}/${METERAI_QUOTA}`
  }
}

export function normalizeEmail(email) {
  return String(email || "").trim().toLowerCase()
}

export function validName(name) {
  return String(name || "").trim() !== ""
}

export function validEmail(email) {
  const trimmed = String(email || "").trim()
  const parts = trimmed.split("@")
  if (parts.length !== 2) return false
  const [local, domain] = parts
  if (!local || !domain) return false
  const domainParts = domain.split(".")
  return domainParts.length >= 2 && domainParts.every((part) => part.length > 0)
}

export function consecutiveSteps(steps) {
  if (!steps.every((step) => Number.isInteger(step) && step >= 1)) return false
  const unique = [...new Set(steps)].sort((a, b) => a - b)
  if (unique[0] !== 1) return false
  return unique.every((step, index) => step === index + 1)
}

export function groupByStep(recipients) {
  const sorted = recipients
    .map((recipient, index) => ({ recipient, index }))
    .sort((a, b) => {
      const stepA = Number.isInteger(a.recipient.step) && a.recipient.step >= 1 ? a.recipient.step : 1
      const stepB = Number.isInteger(b.recipient.step) && b.recipient.step >= 1 ? b.recipient.step : 1
      if (stepA !== stepB) return stepA - stepB
      return a.index - b.index
    })

  const groups = []
  sorted.forEach(({ recipient }) => {
    const step = Number.isInteger(recipient.step) && recipient.step >= 1 ? recipient.step : 1
    const last = groups[groups.length - 1]
    if (last && last.step === step) {
      last.recipients.push(recipient)
    } else {
      groups.push({ step, recipients: [recipient] })
    }
  })
  return groups
}

export function flattenGroups(groups) {
  return groups.flatMap((group, index) =>
    group.recipients.map((recipient) => ({ ...recipient, step: index + 1 }))
  )
}

export function renormalizeSteps(recipients) {
  return flattenGroups(groupByStep(recipients))
}

function locateRecipient(recipients, id) {
  const groups = groupByStep(recipients)
  for (let groupIndex = 0; groupIndex < groups.length; groupIndex += 1) {
    const indexInGroup = groups[groupIndex].recipients.findIndex((recipient) => recipient.id === id)
    if (indexInGroup >= 0) {
      return { groups, groupIndex, indexInGroup }
    }
  }
  return null
}

function sameRecipients(left, right) {
  return left.length === right.length && left.every((recipient, index) => (
    recipient.id === right[index].id && recipient.step === right[index].step
  ))
}

export function moveRecipient(recipients, id, direction) {
  const found = locateRecipient(recipients, id)
  if (!found) return recipients

  const { groups, groupIndex, indexInGroup } = found
  const group = groups[groupIndex]
  const recipient = group.recipients[indexInGroup]

  if (direction === "up") {
    if (group.recipients.length > 1) {
      groups[groupIndex] = { ...group, recipients: group.recipients.filter((_, index) => index !== indexInGroup) }
      groups.splice(groupIndex, 0, { step: 0, recipients: [recipient] })
      return flattenGroups(groups)
    }
    if (groupIndex === 0) return recipients
    const previous = groups[groupIndex - 1]
    groups[groupIndex - 1] = group
    groups[groupIndex] = previous
    return flattenGroups(groups)
  }

  if (direction === "down") {
    if (group.recipients.length > 1) {
      groups[groupIndex] = { ...group, recipients: group.recipients.filter((_, index) => index !== indexInGroup) }
      groups.splice(groupIndex + 1, 0, { step: 0, recipients: [recipient] })
      return flattenGroups(groups)
    }
    if (groupIndex === groups.length - 1) return recipients
    const next = groups[groupIndex + 1]
    groups[groupIndex + 1] = group
    groups[groupIndex] = next
    return flattenGroups(groups)
  }

  return recipients
}

export function mergeRecipient(recipients, id, direction) {
  const found = locateRecipient(recipients, id)
  if (!found) return recipients

  const { groups, groupIndex, indexInGroup } = found
  const group = groups[groupIndex]
  const recipient = group.recipients[indexInGroup]
  const remaining = group.recipients.filter((_, index) => index !== indexInGroup)

  if (direction === "previous") {
    if (groupIndex === 0) return recipients
    groups[groupIndex - 1] = {
      ...groups[groupIndex - 1],
      recipients: [...groups[groupIndex - 1].recipients, recipient]
    }
    if (remaining.length === 0) groups.splice(groupIndex, 1)
    else groups[groupIndex] = { ...group, recipients: remaining }
    return flattenGroups(groups)
  }

  if (direction === "next") {
    if (groupIndex === groups.length - 1) return recipients
    groups[groupIndex + 1] = {
      ...groups[groupIndex + 1],
      recipients: [recipient, ...groups[groupIndex + 1].recipients]
    }
    if (remaining.length === 0) groups.splice(groupIndex, 1)
    else groups[groupIndex] = { ...group, recipients: remaining }
    return flattenGroups(groups)
  }

  return recipients
}

export function canMoveRecipient(recipients, id, direction) {
  return !sameRecipients(recipients, moveRecipient(recipients, id, direction))
}

export function canMergeRecipient(recipients, id, direction) {
  return !sameRecipients(recipients, mergeRecipient(recipients, id, direction))
}

export function validateState(recipients, orderMode) {
  const errors = { global: [], rows: recipients.map(() => []) }

  if (recipients.length < 1 || recipients.length > MAX_RECIPIENTS) {
    errors.global.push(`Use between 1 and ${MAX_RECIPIENTS} recipients.`)
  }

  recipients.forEach((recipient, index) => {
    if (!validName(recipient.name)) errors.rows[index].push("Name is required.")
    if (!validEmail(recipient.email)) errors.rows[index].push("Enter a valid email.")
    if (recipient.meterai_count > recipient.signature_count) {
      errors.rows[index].push("eMeterai cannot exceed this recipient's signatures.")
    }
  })

  const seen = new Map()
  recipients.forEach((recipient, index) => {
    const key = normalizeEmail(recipient.email)
    if (!key || !validEmail(recipient.email)) return
    if (seen.has(key)) {
      const first = seen.get(key)
      const message = "This email is already on the document."
      errors.rows[first].push(message)
      errors.rows[index].push(message)
    } else {
      seen.set(key, index)
    }
  })

  if (orderMode === "sequential") {
    const steps = recipients.map((recipient) => recipient.step)
    if (!consecutiveSteps(steps)) {
      errors.global.push("Steps must start at 1 and increase without gaps.")
    }

    recipients.forEach((recipient, index) => {
      if (recipient.meterai_count > 0 && recipient.step !== 1) {
        errors.rows[index].push("A recipient with eMeterai must stay in step 1 so the stamp is affixed before signing starts.")
      }
    })
  }

  const totals = deriveTotals(recipients)
  if (recipients.length > SIGNATURE_QUOTA) {
    errors.global.push(`Not enough signature quota (${recipients.length} needed, ${SIGNATURE_QUOTA} remaining).`)
  }
  if (totals.totalMeterai > METERAI_QUOTA) {
    errors.global.push(`Not enough eMeterai quota (${totals.totalMeterai} needed, ${METERAI_QUOTA} remaining).`)
  }

  return errors
}

export function hasErrors(errors) {
  return errors.global.length > 0 || errors.rows.some((row) => row.length > 0)
}

export function displayMoney(cents) {
  return formatDisplay(cents)
}

export {
  SIGNATURE_PRICE_CENTS,
  METERAI_PRICE_CENTS,
  SIGNATURE_QUOTA,
  METERAI_QUOTA,
  MAX_RECIPIENTS,
  METERAI_MIN,
  METERAI_MAX
}
