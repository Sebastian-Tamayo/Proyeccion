import { ONLINE_API_BASE, STAFF } from '../config'
import type { Reservation, ReservationStatus, StaffUser } from '../types'

type RemoteReservation = Omit<Reservation, 'id'> & { _id?: string; id?: string }

function mapReservation(raw: RemoteReservation): Reservation {
  return {
    id: raw.id || raw._id || '',
    codigo: raw.codigo,
    nombre: raw.nombre,
    telefono: raw.telefono || '',
    fecha: raw.fecha,
    hora: raw.hora,
    personas: Number(raw.personas) || 1,
    notas: raw.notas || '',
    estado: raw.estado,
    createdAt: raw.createdAt,
    updatedAt: raw.updatedAt,
    creadoPor: raw.creadoPor || '',
  }
}

async function parseError(res: Response) {
  try {
    const data = (await res.json()) as { error?: string }
    if (data.error) return data.error
  } catch {
    /* ignore */
  }
  return 'No se pudo conectar. Revisa internet e inténtalo otra vez.'
}

export function fetchStaffDirectory(): Promise<StaffUser[]> {
  return Promise.resolve(STAFF.map(({ id, name }) => ({ id, name })))
}

export async function loginLocal(staffId: string, pin: string): Promise<StaffUser> {
  const user = STAFF.find((s) => s.id === staffId)
  if (!user || user.pin !== String(pin)) {
    throw new Error('PIN incorrecto. Prueba otra vez.')
  }
  return { id: user.id, name: user.name }
}

export async function listReservations(): Promise<Reservation[]> {
  const res = await fetch(ONLINE_API_BASE)
  if (!res.ok) throw new Error(await parseError(res))
  const data = (await res.json()) as RemoteReservation[]
  return data
    .map(mapReservation)
    .sort((a, b) => String(b.createdAt).localeCompare(String(a.createdAt)))
}

export async function createReservation(input: {
  nombre: string
  telefono: string
  fecha: string
  hora: string
  personas: number
  notas: string
  creadoPor: string
}): Promise<Reservation> {
  const now = new Date().toISOString()
  const payload = {
    codigo: `CT-${Math.floor(1000 + Math.random() * 9000)}`,
    nombre: input.nombre,
    telefono: input.telefono,
    fecha: input.fecha,
    hora: input.hora,
    personas: input.personas,
    notas: input.notas,
    estado: 'confirmada' as ReservationStatus,
    createdAt: now,
    updatedAt: now,
    creadoPor: input.creadoPor,
  }
  const res = await fetch(ONLINE_API_BASE, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload),
  })
  if (!res.ok) throw new Error(await parseError(res))
  return mapReservation((await res.json()) as RemoteReservation)
}

export async function updateReservationStatus(
  id: string,
  patch: Partial<Pick<Reservation, 'estado' | 'notas'>>,
): Promise<Reservation> {
  const currentList = await listReservations()
  const current = currentList.find((r) => r.id === id)
  if (!current) throw new Error('Reserva no encontrada')

  const next: Omit<Reservation, 'id'> = {
    codigo: current.codigo,
    nombre: current.nombre,
    telefono: current.telefono,
    fecha: current.fecha,
    hora: current.hora,
    personas: current.personas,
    notas: patch.notas ?? current.notas,
    estado: patch.estado ?? current.estado,
    createdAt: current.createdAt,
    updatedAt: new Date().toISOString(),
    creadoPor: current.creadoPor,
  }

  const res = await fetch(`${ONLINE_API_BASE}/${id}`, {
    method: 'PUT',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(next),
  })
  if (!res.ok) throw new Error(await parseError(res))
  return { id, ...next }
}
