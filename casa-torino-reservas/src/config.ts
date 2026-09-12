/** Configuración de negocio Casa Torino — Gijón */
export const BUSINESS = {
  name: 'Casa Torino',
  slogan: 'Sabor que deja huella',
  tagline: 'Fusión Colombo-Asturiana',
  address: 'Ctra. Ceares, 67, Gijón',
  phone: '612 254 719',
  phoneE164: '+34612254719',
  whatsapp: '34612254719',
  emailContacto: 'reservas@casatorino.es',
  inauguration: '2025-09-12',
  openFrom: '12:00',
  closeAt: '23:30',
  lastReservation: '22:00',
  maxPartySize: 12,
  minPartySize: 1,
  /** Capacidad orientativa por franja horaria */
  capacityPerSlot: 28,
  slotIntervalMinutes: 30,
  /** Días de antelación máximos para reservar */
  maxDaysAhead: 60,
  timezone: 'Europe/Madrid',
} as const

/**
 * Correos del personal autorizados a gestionar reservas.
 * En producción, añade aquí los Gmail del equipo.
 */
export const ADMIN_EMAILS = [
  'admin@casatorino.es',
  'lorena@casatorino.es',
  'yuli@casatorino.es',
  'dayana@casatorino.es',
  // Demo: cualquier cuenta Google cuyo email esté aquí, o el modo demo local
  'demo@casatorino.es',
]

export const ZONAS: { value: import('./types').ZonaPreferida; label: string }[] = [
  { value: 'sin_preferencia', label: 'Sin preferencia' },
  { value: 'interior', label: 'Interior / Salón' },
  { value: 'barra', label: 'Barra' },
  { value: 'terraza', label: 'Terraza (si disponible)' },
]

export const OCASIONES: { value: import('./types').Ocasion; label: string }[] = [
  { value: 'ninguna', label: 'Ninguna en especial' },
  { value: 'cumpleanos', label: 'Cumpleaños' },
  { value: 'aniversario', label: 'Aniversario' },
  { value: 'cita', label: 'Cita / Pareja' },
  { value: 'negocios', label: 'Negocios' },
  { value: 'familia', label: 'Comida familiar' },
  { value: 'otra', label: 'Otra' },
]

export const STATUS_LABELS: Record<import('./types').ReservationStatus, string> = {
  pendiente: 'Pendiente',
  confirmada: 'Confirmada',
  cancelada: 'Cancelada',
  completada: 'Completada',
  no_show: 'No presentado',
}

export const HORAS_RESERVA = [
  '12:00', '12:30', '13:00', '13:30', '14:00', '14:30', '15:00', '15:30',
  '16:00', '16:30', '17:00', '17:30', '18:00', '18:30', '19:00', '19:30',
  '20:00', '20:30', '21:00', '21:30', '22:00',
]
