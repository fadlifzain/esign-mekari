export function formatApi(cents) {
  const negative = cents < 0
  const abs = Math.abs(cents)
  const whole = Math.trunc(abs / 100)
  const fraction = String(abs % 100).padStart(2, "0")
  return `${negative ? "-" : ""}${whole}.${fraction}`
}

export function formatDisplay(cents) {
  const negative = cents < 0
  const abs = Math.abs(cents)
  const whole = Math.trunc(abs / 100)
  const fraction = String(abs % 100).padStart(2, "0")
  const grouped = String(whole).replace(/\B(?=(\d{3})+(?!\d))/g, ".")
  return `${negative ? "-" : ""}Rp${grouped},${fraction}`
}
