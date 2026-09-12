/** Casa Torino — Gijón */
export const BUSINESS = {
  name: 'Casa Torino',
  slogan: 'Sabor que deja huella',
  address: 'Ctra. Ceares, 67, Gijón',
  phone: '612 254 719',
  whatsapp: '34612254719',
  maxPartySize: 12,
  minPartySize: 1,
} as const

/** Gmail del personal autorizado (producción). */
export const ADMIN_EMAILS = [
  'admin@casatorino.es',
  'lorena@casatorino.es',
  'yuli@casatorino.es',
  'dayana@casatorino.es',
  'demo@casatorino.es',
]

export const STATUS_LABELS: Record<import('./types').ReservationStatus, string> = {
  confirmada: 'Confirmada',
  cancelada: 'Cancelada',
  completada: 'Hecha',
  no_show: 'No vino',
}

export const HORAS_RAPIDAS = [
  '12:00',
  '12:30',
  '13:00',
  '13:30',
  '14:00',
  '14:30',
  '15:00',
  '19:00',
  '19:30',
  '20:00',
  '20:30',
  '21:00',
  '21:30',
  '22:00',
]
