import {
  createContext,
  useCallback,
  useContext,
  useEffect,
  useMemo,
  useState,
  type ReactNode,
} from 'react'
import { isFirebaseConfigured } from './lib/firebase'
import {
  loginDemoStaff,
  loginWithGoogle,
  logoutStaff,
  seedDemoIfEmpty,
  watchAuth,
} from './lib/reservations'
import type { StaffUser } from './types'

interface AuthContextValue {
  user: StaffUser | null
  loading: boolean
  firebaseReady: boolean
  loginGoogle: () => Promise<void>
  loginDemo: () => void
  logout: () => Promise<void>
}

const AuthContext = createContext<AuthContextValue | null>(null)

export function AuthProvider({ children }: { children: ReactNode }) {
  const [user, setUser] = useState<StaffUser | null>(null)
  const [loading, setLoading] = useState(true)

  useEffect(() => {
    seedDemoIfEmpty()
    const unsub = watchAuth((u) => {
      setUser(u)
      setLoading(false)
    })
    const t = window.setTimeout(() => setLoading(false), 400)
    return () => {
      unsub()
      window.clearTimeout(t)
    }
  }, [])

  const loginGoogle = useCallback(async () => {
    const staff = await loginWithGoogle()
    if (!staff.isAdmin) {
      await logoutStaff()
      throw new Error('Cuenta no autorizada. Añade tu Gmail en ADMIN_EMAILS.')
    }
    setUser(staff)
  }, [])

  const loginDemo = useCallback(() => setUser(loginDemoStaff()), [])

  const logout = useCallback(async () => {
    await logoutStaff()
    setUser(null)
  }, [])

  const value = useMemo(
    () => ({
      user,
      loading,
      firebaseReady: isFirebaseConfigured,
      loginGoogle,
      loginDemo,
      logout,
    }),
    [user, loading, loginGoogle, loginDemo, logout],
  )

  return <AuthContext.Provider value={value}>{children}</AuthContext.Provider>
}

export function useAuth() {
  const ctx = useContext(AuthContext)
  if (!ctx) throw new Error('useAuth debe usarse dentro de AuthProvider')
  return ctx
}
