import type { Reservation } from '../types'

const KEY = 'casa-torino-reservas-v1'

export function loadLocalReservations(): Reservation[] {
  try {
    const raw = localStorage.getItem(KEY)
    if (!raw) return []
    const parsed = JSON.parse(raw) as Reservation[]
    return Array.isArray(parsed) ? parsed : []
  } catch {
    return []
  }
}

export function saveLocalReservations(items: Reservation[]) {
  localStorage.setItem(KEY, JSON.stringify(items))
}

export function upsertLocalReservation(item: Reservation) {
  const all = loadLocalReservations()
  const idx = all.findIndex((r) => r.id === item.id)
  if (idx >= 0) all[idx] = item
  else all.unshift(item)
  saveLocalReservations(all)
  return all
}

export function generateCodigo(): string {
  const n = Math.floor(1000 + Math.random() * 9000)
  return `CT-${n}`
}

export function generateId(): string {
  if (typeof crypto !== 'undefined' && crypto.randomUUID) {
    return crypto.randomUUID()
  }
  return `id-${Date.now()}-${Math.random().toString(36).slice(2, 9)}`
}
