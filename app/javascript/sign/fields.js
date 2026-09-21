import { FIELD_BOUNDS } from "sign/config"

export function fieldInBounds(kind, x, y) {
  const bounds = FIELD_BOUNDS[kind]
  if (!bounds) return false
  return Number.isInteger(x) && Number.isInteger(y) &&
    x >= bounds.minX && x <= bounds.maxX &&
    y >= bounds.minY && y <= bounds.maxY
}

export function clampField(kind, x, y) {
  const bounds = FIELD_BOUNDS[kind]
  if (!bounds) return { x: 0, y: 0 }

  const toInt = (value) => (Number.isInteger(value) ? value : 0)
  return {
    x: Math.min(bounds.maxX, Math.max(bounds.minX, toInt(x))),
    y: Math.min(bounds.maxY, Math.max(bounds.minY, toInt(y)))
  }
}
