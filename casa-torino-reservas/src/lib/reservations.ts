import {
  createUserWithEmailAndPassword,
  onAuthStateChanged,
  signInWithEmailAndPassword,
  signInWithPopup,
  signOut,
  type User,
} from 'firebase/auth'
import {
  addDoc,
  collection,
  doc,
  onSnapshot,
  orderBy,
  query,
  updateDoc,
  type Unsubscribe,
} from 'firebase/firestore'
import { ADMIN_EMAILS } from '../config'
import type { Reservation, ReservationStatus, StaffUser } from '../types'
import { auth, db, googleProvider, isFirebaseConfigured } from './firebase'
import {
  generateCodigo,
  generateId,
  loadLocalReservations,
  upsertLocalReservation,
} from './storage'

const DEMO_USER_KEY = 'casa-torino-demo-staff'

export function isAdminEmail(email: string | null | undefined): boolean {
  if (!email) return false
  const normalized = email.trim().toLowerCase()
  // En modo demo, cualquier sesión demo es admin
  if (normalized.endsWith('@casatorino.es')) return true
  return ADMIN_EMAILS.map((e) => e.toLowerCase()).includes(normalized)
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
    const raw = localStorage.getItem(DEMO_USER_KEY)
    return raw ? (JSON.parse(raw) as StaffUser) : null
  } catch {
    return null
  }
}

export function setDemoStaff(user: StaffUser | null) {
  if (!user) localStorage.removeItem(DEMO_USER_KEY)
  else localStorage.setItem(DEMO_USER_KEY, JSON.stringify(user))
}

/** Entrar como personal en modo demo (sin Firebase). */
export function loginDemoStaff(): StaffUser {
  const user: StaffUser = {
    uid: 'demo-staff',
    email: 'demo@casatorino.es',
    displayName: 'Personal Casa Torino',
    isAdmin: true,
  }
  setDemoStaff(user)
  return user
}

export function logoutDemoStaff() {
  setDemoStaff(null)
}

export async function loginWithGoogle(): Promise<StaffUser> {
  if (!isFirebaseConfigured || !auth || !googleProvider) {
    throw new Error('Firebase no configurado. Usa el modo demo o añade las claves en .env')
  }
  const result = await signInWithPopup(auth, googleProvider)
  return toStaffUser(result.user)
}

export async function logoutStaff() {
  logoutDemoStaff()
  if (auth) await signOut(auth)
}

export function watchAuth(callback: (user: StaffUser | null) => void): () => void {
  // Demo primero
  const demo = getDemoStaff()
  if (demo) callback(demo)

  if (!isFirebaseConfigured || !auth) {
    return () => undefined
  }

  const unsub = onAuthStateChanged(auth, (user) => {
    if (user) callback(toStaffUser(user))
    else if (!getDemoStaff()) callback(null)
  })
  return unsub
}

export type NewReservationInput = Omit<
  Reservation,
  'id' | 'codigo' | 'estado' | 'createdAt' | 'updatedAt' | 'origen' | 'mesaAsignada' | 'notasInternas'
>

export async function createReservation(input: NewReservationInput): Promise<Reservation> {
  const now = new Date().toISOString()
  const base: Reservation = {
    ...input,
    id: generateId(),
    codigo: generateCodigo(),
    estado: 'pendiente',
    createdAt: now,
    updatedAt: now,
    origen: 'web',
  }

  if (isFirebaseConfigured && db) {
    const { id: _ignore, ...payload } = base
    const ref = await addDoc(collection(db, 'reservas'), payload)
    return { ...base, id: ref.id }
  }

  upsertLocalReservation(base)
  return base
}

export async function updateReservationStatus(
  id: string,
  patch: Partial<Pick<Reservation, 'estado' | 'mesaAsignada' | 'notasInternas'>>,
): Promise<void> {
  const updatedAt = new Date().toISOString()

  if (isFirebaseConfigured && db) {
    await updateDoc(doc(db, 'reservas', id), { ...patch, updatedAt })
    return
  }

  const all = loadLocalReservations()
  const found = all.find((r) => r.id === id)
  if (!found) throw new Error('Reserva no encontrada')
  upsertLocalReservation({ ...found, ...patch, updatedAt })
}

export function watchReservations(callback: (items: Reservation[]) => void): Unsubscribe | (() => void) {
  if (isFirebaseConfigured && db) {
    const q = query(collection(db, 'reservas'), orderBy('createdAt', 'desc'))
    return onSnapshot(q, (snap) => {
      const items = snap.docs.map((d) => ({ id: d.id, ...(d.data() as Omit<Reservation, 'id'>) }))
      callback(items)
    })
  }

  const emit = () => callback(loadLocalReservations())
  emit()
  const onStorage = (e: StorageEvent) => {
    if (e.key === 'casa-torino-reservas-v1') emit()
  }
  window.addEventListener('storage', onStorage)
  // Poll ligero para misma pestaña tras formularios
  const interval = window.setInterval(emit, 2000)
  return () => {
    window.removeEventListener('storage', onStorage)
    window.clearInterval(interval)
  }
}

export function seedDemoIfEmpty() {
  if (isFirebaseConfigured) return
  const current = loadLocalReservations()
  if (current.length > 0) return

  const today = new Date()
  const yyyy = today.toISOString().slice(0, 10)
  const samples: Reservation[] = [
    {
      id: generateId(),
      codigo: 'CT-2025',
      nombre: 'María Fernández',
      telefono: '612111222',
      email: 'maria@email.com',
      fecha: yyyy,
      hora: '14:00',
      personas: 4,
      zona: 'interior',
      ocasion: 'familia',
      notas: 'Niño en trona si es posible',
      estado: 'pendiente' as ReservationStatus,
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      origen: 'web',
    },
    {
      id: generateId(),
      codigo: 'CT-2026',
      nombre: 'Carlos Ruiz',
      telefono: '655444333',
      email: 'carlos@email.com',
      fecha: yyyy,
      hora: '21:00',
      personas: 2,
      zona: 'barra',
      ocasion: 'cita',
      notas: '',
      estado: 'confirmada' as ReservationStatus,
      mesaAsignada: 'Mesa 3',
      createdAt: new Date().toISOString(),
      updatedAt: new Date().toISOString(),
      origen: 'web',
    },
  ]
  samples.forEach(upsertLocalReservation)
}

// Helpers opcionales si más adelante quieren email/password además de Google
export async function registerEmail(email: string, password: string) {
  if (!auth) throw new Error('Firebase no configurado')
  return createUserWithEmailAndPassword(auth, email, password)
}

export async function loginEmail(email: string, password: string) {
  if (!auth) throw new Error('Firebase no configurado')
  return signInWithEmailAndPassword(auth, email, password)
}
