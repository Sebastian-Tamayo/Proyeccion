import { useEffect, useMemo, useState, type FormEvent } from 'react'
import { useAuth } from '../auth'
import { BUSINESS, HORAS_RAPIDAS, STATUS_LABELS } from '../config'
import { isFirebaseConfigured } from '../lib/firebase'
import {
  createReservation,
  updateReservationStatus,
  watchReservations,
} from '../lib/reservations'
import type { Reservation, ReservationStatus } from '../types'

function todayISO() {
  const d = new Date()
  return new Date(d.getTime() - d.getTimezoneOffset() * 60_000).toISOString().slice(0, 10)
}

function nearestHour() {
  const now = new Date()
  const h = now.getHours()
  const m = now.getMinutes()
  const candidate =
    m < 15
      ? `${String(h).padStart(2, '0')}:00`
      : m < 45
        ? `${String(h).padStart(2, '0')}:30`
        : `${String(Math.min(h + 1, 23)).padStart(2, '0')}:00`
  return HORAS_RAPIDAS.includes(candidate) ? candidate : '14:00'
}

export function StaffPage() {
  const { user, loading, firebaseReady, loginGoogle, loginDemo } = useAuth()
  const [items, setItems] = useState<Reservation[]>([])
  const [nombre, setNombre] = useState('')
  const [telefono, setTelefono] = useState('')
  const [fecha, setFecha] = useState(todayISO())
  const [hora, setHora] = useState(nearestHour())
  const [personas, setPersonas] = useState(2)
  const [notas, setNotas] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [flash, setFlash] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)
  const [soloHoy, setSoloHoy] = useState(true)

  useEffect(() => {
    if (!user?.isAdmin) return
    return watchReservations(setItems)
  }, [user])

  const lista = useMemo(() => {
    const hoy = todayISO()
    return items
      .filter((r) => (soloHoy ? r.fecha === hoy : true))
      .filter((r) => r.estado !== 'cancelada')
      .sort((a, b) => `${a.fecha}${a.hora}`.localeCompare(`${b.fecha}${b.hora}`))
  }, [items, soloHoy])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    if (!nombre.trim()) {
      setError('Pon el nombre del cliente.')
      return
    }
    setSubmitting(true)
    try {
      const r = await createReservation({
        nombre: nombre.trim(),
        telefono: telefono.trim(),
        fecha,
        hora,
        personas,
        notas: notas.trim(),
        creadoPor: user?.email ?? 'personal',
      })
      setFlash(`✓ ${r.codigo} · ${r.nombre} · ${r.personas}p · ${r.hora}`)
      setNombre('')
      setTelefono('')
      setNotas('')
      setPersonas(2)
      setHora(nearestHour())
      setFecha(todayISO())
      if (!isFirebaseConfigured) {
        setItems((prev) => [r, ...prev.filter((x) => x.id !== r.id)])
      }
      window.setTimeout(() => setFlash(null), 3000)
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo guardar')
    } finally {
      setSubmitting(false)
    }
  }

  async function setEstado(id: string, estado: ReservationStatus) {
    await updateReservationStatus(id, { estado })
    if (!isFirebaseConfigured) {
      setItems((prev) =>
        prev.map((r) => (r.id === id ? { ...r, estado, updatedAt: new Date().toISOString() } : r)),
      )
    }
  }

  if (loading) {
    return (
      <main className="page">
        <div className="card center">Cargando…</div>
      </main>
    )
  }

  if (!user?.isAdmin) {
    return (
      <main className="page">
        <div className="card login-box">
          <img src="/logo.jpg" alt="Casa Torino" />
          <h1>Reservas</h1>
          <p className="muted">Solo personal. Anota la mesa cuando alguien se acerque a reservar.</p>
          {error && <div className="alert alert-error">{error}</div>}
          {!firebaseReady && (
            <div className="alert alert-info">Demo lista: entra y prueba el alta rápida.</div>
          )}
          <div className="stack">
            {firebaseReady ? (
              <button
                className="btn btn-gold btn-lg"
                type="button"
                onClick={() => {
                  setError(null)
                  void loginGoogle().catch((err: unknown) =>
                    setError(err instanceof Error ? err.message : 'Error de Google'),
                  )
                }}
              >
                Entrar con Google
              </button>
            ) : (
              <button className="btn btn-gold btn-lg" type="button" onClick={loginDemo}>
                Entrar
              </button>
            )}
            {firebaseReady && (
              <button className="btn btn-outline" type="button" onClick={loginDemo}>
                Probar demo
              </button>
            )}
          </div>
        </div>
      </main>
    )
  }

  return (
    <main className="page">
      <section className="card">
        <div className="section-head">
          <div>
            <h1>Nueva reserva</h1>
            <p className="muted">Rápido · {user.displayName}</p>
          </div>
        </div>

        {flash && <div className="alert alert-ok">{flash}</div>}
        {error && <div className="alert alert-error">{error}</div>}

        <form className="quick-form" onSubmit={(e) => void onSubmit(e)}>
          <label>
            Nombre *
            <input
              autoFocus
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              placeholder="Nombre del cliente"
              autoComplete="off"
              required
            />
          </label>

          <label>
            Teléfono
            <input
              value={telefono}
              onChange={(e) => setTelefono(e.target.value)}
              placeholder="Opcional"
              inputMode="tel"
              autoComplete="off"
            />
          </label>

          <div>
            <span className="field-label">Personas</span>
            <div className="chip-row">
              {Array.from({ length: 8 }, (_, i) => i + 1).map((n) => (
                <button
                  key={n}
                  type="button"
                  className={`chip ${personas === n ? 'chip-on' : ''}`}
                  onClick={() => setPersonas(n)}
                >
                  {n}
                </button>
              ))}
              <button
                type="button"
                className={`chip ${personas > 8 ? 'chip-on' : ''}`}
                onClick={() => setPersonas(Math.min(BUSINESS.maxPartySize, Math.max(9, personas)))}
              >
                9+
              </button>
            </div>
          </div>

          <div className="two-cols">
            <label>
              Día
              <input type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} required />
            </label>
            <label>
              Hora
              <select value={hora} onChange={(e) => setHora(e.target.value)} required>
                {HORAS_RAPIDAS.map((h) => (
                  <option key={h} value={h}>
                    {h}
                  </option>
                ))}
              </select>
            </label>
          </div>

          <label>
            Nota
            <input
              value={notas}
              onChange={(e) => setNotas(e.target.value)}
              placeholder="Opcional"
              maxLength={120}
            />
          </label>

          <button className="btn btn-gold btn-lg" type="submit" disabled={submitting}>
            {submitting ? 'Guardando…' : 'Guardar'}
          </button>
        </form>
      </section>

      <section className="card list-card">
        <div className="section-head">
          <h2>{soloHoy ? 'Hoy' : 'Todas'}</h2>
          <button className="btn btn-ghost" type="button" onClick={() => setSoloHoy((v) => !v)}>
            {soloHoy ? 'Ver todas' : 'Solo hoy'}
          </button>
        </div>

        {lista.length === 0 && <p className="muted">No hay reservas{soloHoy ? ' para hoy' : ''}.</p>}

        <ul className="res-list">
          {lista.map((r) => (
            <li key={r.id} className="res-item">
              <div className="res-main">
                <div className="res-title">
                  <b>{r.hora}</b> · {r.nombre} · {r.personas}p
                </div>
                <div className="muted small">
                  {r.codigo}
                  {r.telefono ? ` · ${r.telefono}` : ''}
                  {r.notas ? ` · ${r.notas}` : ''}
                  {' · '}
                  <span className={`badge badge-${r.estado}`}>{STATUS_LABELS[r.estado]}</span>
                </div>
              </div>
              <div className="row-actions">
                {r.estado === 'confirmada' && (
                  <>
                    <button
                      className="btn btn-ok"
                      type="button"
                      onClick={() => void setEstado(r.id, 'completada')}
                    >
                      Hecha
                    </button>
                    <button
                      className="btn btn-ghost"
                      type="button"
                      onClick={() => void setEstado(r.id, 'no_show')}
                    >
                      No vino
                    </button>
                    <button
                      className="btn btn-danger"
                      type="button"
                      onClick={() => void setEstado(r.id, 'cancelada')}
                    >
                      Anular
                    </button>
                  </>
                )}
                {r.telefono && (
                  <a
                    className="btn btn-outline"
                    href={`https://wa.me/34${r.telefono.replace(/\D/g, '').replace(/^34/, '')}`}
                    target="_blank"
                    rel="noreferrer"
                  >
                    WA
                  </a>
                )}
              </div>
            </li>
          ))}
        </ul>
      </section>

      <p className="footer-mini">
        {BUSINESS.name} · {BUSINESS.address}
      </p>
    </main>
  )
}
