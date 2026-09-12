import type { Reservation, ReservationStatus, StaffUser } from '../types'

async function api<T>(url: string, init?: RequestInit): Promise<T> {
  const res = await fetch(url, {
    headers: { 'Content-Type': 'application/json', ...(init?.headers || {}) },
    ...init,
  })
  if (!res.ok) {
    let message = 'Error del servidor local'
    try {
      const data = (await res.json()) as { error?: string }
      if (data.error) message = data.error
    } catch {
      /* ignore */
    }
    throw new Error(message)
  }
  return res.json() as Promise<T>
}

export function fetchStaffDirectory() {
  return api<StaffUser[]>('/api/staff')
}

export function loginLocal(staffId: string, pin: string) {
  return api<StaffUser>('/api/login', {
    method: 'POST',
    body: JSON.stringify({ staffId, pin }),
  })
}

export function listReservations() {
  return api<Reservation[]>('/api/reservas')
}

export function createReservation(input: {
  nombre: string
  telefono: string
  fecha: string
  hora: string
  personas: number
  notas: string
  creadoPor: string
}) {
  return api<Reservation>('/api/reservas', {
    method: 'POST',
    body: JSON.stringify(input),
  })
}

export function updateReservationStatus(
  id: string,
  patch: Partial<Pick<Reservation, 'estado' | 'notas'>> & { estado?: ReservationStatus },
) {
  return api<Reservation>(`/api/reservas/${id}`, {
    method: 'PATCH',
    body: JSON.stringify(patch),
  })
}
