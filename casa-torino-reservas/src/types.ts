export type ReservationStatus =
  | 'pendiente'
  | 'confirmada'
  | 'cancelada'
  | 'completada'
  | 'no_show'

export type ZonaPreferida = 'sin_preferencia' | 'interior' | 'barra' | 'terraza'

export type Ocasion =
  | 'ninguna'
  | 'cumpleanos'
  | 'aniversario'
  | 'cita'
  | 'negocios'
  | 'familia'
  | 'otra'

export interface Reservation {
  id: string
  codigo: string
  nombre: string
  telefono: string
  email: string
  fecha: string
  hora: string
  personas: number
  zona: ZonaPreferida
  ocasion: Ocasion
  notas: string
  estado: ReservationStatus
  mesaAsignada?: string
  notasInternas?: string
  createdAt: string
  updatedAt: string
  origen: 'web'
}

export interface StaffUser {
  uid: string
  email: string
  displayName: string
  photoURL?: string
  isAdmin: boolean
}

export interface AvailabilitySlot {
  hora: string
  disponible: boolean
  plazasRestantes: number
}
