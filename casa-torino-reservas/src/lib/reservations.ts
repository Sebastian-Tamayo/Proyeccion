import { onAuthStateChanged, signInWithPopup, signOut, type User } from 'firebase/auth'
import {
  addDoc,
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
} from 'firebase/firestore'
import { ADMIN_EMAILS } from '../config'
import type { Reservation, ReservationStatus, StaffUser } from '../types'
import { auth, db, googleProvider, isFirebaseConfigured } from './firebase'
import {
  STORAGE_KEY,
  generateCodigo,
  generateId,
  loadLocalReservations,
  upsertLocalReservation,
} from './storage'

const DEMO_KEY = 'casa-torino-demo-staff'

export function isAdminEmail(email: string | null | undefined): boolean {
  if (!email) return false
  const n = email.trim().toLowerCase()
  if (n.endsWith('@casatorino.es')) return true
  return ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(n)
}

export function toStaffUser(user: User): StaffUser {
  return {
    uid: user.uid,
    email: user.email ?? '',
    displayName: user.displayName ?? user.email ?? 'Personal',
    photoURL: user.photoURL ?? undefined,
    isAdmin: isAdminEmail(user.email),
  }
}

export function getDemoStaff(): StaffUser | null {
  try {
    const raw = localStorage.getItem(DEMO_KEY)
    return raw ? (JSON.parse(raw) as StaffUser) : null
  } catch {
    return null
  }
}

export function loginDemoStaff(): StaffUser {
  const user: StaffUser = {
    uid: 'demo-staff',
    email: 'demo@casatorino.es',
    displayName: 'Personal Casa Torino',
    isAdmin: true,
  }
  localStorage.setItem(DEMO_KEY, JSON.stringify(user))
  return user
}

export async function loginWithGoogle(): Promise<StaffUser> {
  if (!isFirebaseConfigured || !auth || !googleProvider) {
    throw new Error('Firebase no configurado. Usa el modo demo.')
  }
  const result = await signInWithPopup(auth, googleProvider)
  return toStaffUser(result.user)
}

export async function logoutStaff() {
  localStorage.removeItem(DEMO_KEY)
  if (auth) await signOut(auth)
}

export function watchAuth(cb: (user: StaffUser | null) => void): () => void {
  const demo = getDemoStaff()
  if (demo) cb(demo)
  if (!isFirebaseConfigured || !auth) return () => undefined
  return onAuthStateChanged(auth, (user) => {
    if (user) cb(toStaffUser(user))
    else if (!getDemoStaff()) cb(null)
  })
}

export type NewReservationInput = {
  nombre: string
  telefono: string
  fecha: string
  hora: string
  personas: number
  notas: string
  creadoPor: string
}

export async function createReservation(input: NewReservationInput): Promise<Reservation> {
  const now = new Date().toISOString()
  const base: Reservation = {
    ...input,
    id: generateId(),
    codigo: generateCodigo(),
    estado: 'confirmada',
    createdAt: now,
    updatedAt: now,
  }

  if (isFirebaseConfigured && db) {
    const { id: _id, ...payload } = base
    const ref = await addDoc(collection(db, 'reservas'), payload)
    return { ...base, id: ref.id }
  }

  upsertLocalReservation(base)
  return base
}

export async function updateReservationStatus(
  id: string,
  patch: Partial<Pick<Reservation, 'estado' | 'notas'>>,
): Promise<void> {
  const updatedAt = new Date().toISOString()
  if (isFirebaseConfigured && db) {
    await updateDoc(doc(db, 'reservas', id), { ...patch, updatedAt })
    return
  }
  const found = loadLocalReservations().find((r) => r.id === id)
  if (!found) throw new Error('Reserva no encontrada')
  upsertLocalReservation({ ...found, ...patch, updatedAt })
}

export function watchReservations(cb: (items: Reservation[]) => void): () => void {
  if (isFirebaseConfigured && db) {
    const q = query(collection(db, 'reservas'), orderBy('createdAt', 'desc'))
    return onSnapshot(q, (snap) => {
      cb(snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Reservation, 'id'>) })))
    })
  }

  const emit = () => cb(loadLocalReservations())
  emit()
  const onStorage = (e: StorageEvent) => {
    if (e.key === STORAGE_KEY) emit()
  }
  window.addEventListener('storage', onStorage)
  const interval = window.setInterval(emit, 1500)
  return () => {
    window.removeEventListener('storage', onStorage)
    window.clearInterval(interval)
  }
}

export function seedDemoIfEmpty() {
  if (isFirebaseConfigured) return
  if (loadLocalReservations().length > 0) return
  const today = new Date()
  const yyyy = new Date(today.getTime() - today.getTimezoneOffset() * 60_000)
    .toISOString()
    .slice(0, 10)
  upsertLocalReservation({
    id: generateId(),
    codigo: 'CT-1001',
    nombre: 'María',
    telefono: '612111222',
    fecha: yyyy,
    hora: '14:00',
    personas: 4,
    notas: '',
    estado: 'confirmada' as ReservationStatus,
    createdAt: new Date().toISOString(),
    updatedAt: new Date().toISOString(),
    creadoPor: 'demo@casatorino.es',
  })
}
