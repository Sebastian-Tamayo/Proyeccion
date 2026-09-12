import { useEffect, useMemo, useState } from 'react'
import { useAuth } from '../auth'
import { OCASIONES, STATUS_LABELS, ZONAS } from '../config'
import { isFirebaseConfigured } from '../lib/firebase'
import { updateReservationStatus, watchReservations } from '../lib/reservations'
import type { Reservation, ReservationStatus } from '../types'

function labelZona(v: Reservation['zona']) {
  return ZONAS.find((z) => z.value === v)?.label ?? v
}
function labelOcasion(v: Reservation['ocasion']) {
  return OCASIONES.find((o) => o.value === v)?.label ?? v
}

export function AdminPage() {
  const { user, loading, firebaseReady, loginGoogle, loginDemo, logout } = useAuth()
  const [items, setItems] = useState<Reservation[]>([])
  const [q, setQ] = useState('')
  const [estado, setEstado] = useState<'todos' | ReservationStatus>('todos')
  const [fecha, setFecha] = useState('')
  const [busyId, setBusyId] = useState<string | null>(null)
  const [error, setError] = useState<string | null>(null)

  useEffect(() => {
    if (!user?.isAdmin) return
    return watchReservations(setItems)
  }, [user])

  const filtered = useMemo(() => {
    const query = q.trim().toLowerCase()
    return items.filter((r) => {
      if (estado !== 'todos' && r.estado !== estado) return false
      if (fecha && r.fecha !== fecha) return false
      if (!query) return true
      const blob = `${r.codigo} ${r.nombre} ${r.telefono} ${r.email} ${r.notas}`.toLowerCase()
      return blob.includes(query)
    })
  }, [items, q, estado, fecha])

  const stats = useMemo(() => {
    const base = {
      total: items.length,
      pendiente: 0,
      confirmada: 0,
      cancelada: 0,
      completada: 0,
    }
    for (const r of items) {
      if (r.estado in base) base[r.estado as keyof typeof base]++
    }
    return base
  }, [items])

  async function patch(
    id: string,
    data: Partial<Pick<Reservation, 'estado' | 'mesaAsignada' | 'notasInternas'>>,
  ) {
    setBusyId(id)
    setError(null)
    try {
      await updateReservationStatus(id, data)
      // En modo local, refrescar inmediatamente
      if (!isFirebaseConfigured) {
        setItems((prev) =>
          prev.map((r) => (r.id === id ? { ...r, ...data, updatedAt: new Date().toISOString() } : r)),
        )
      }
    } catch (err) {
      setError(err instanceof Error ? err.message : 'Error al actualizar')
    } finally {
      setBusyId(null)
    }
  }

  if (loading) {
    return (
      <main className="page">
        <div className="card login-box">Cargando…</div>
      </main>
    )
  }

  if (!user?.isAdmin) {
    return (
      <main className="page">
        <div className="card login-box">
          <img src="/logo.jpg" alt="Casa Torino" />
          <h2>Acceso personal</h2>
          <p className="muted">
            Autenticación con <b>una sola plataforma: Google</b>. Solo el equipo autorizado gestiona las
            reservas.
          </p>
          {error && <div className="alert alert-error">{error}</div>}
          {!firebaseReady && (
            <div className="alert alert-info">
              Modo demo activo (sin Firebase). Puedes entrar como personal ahora. Para producción, configura
              Google en el archivo <code>.env</code>.
            </div>
          )}
          <div style={{ display: 'grid', gap: '0.75rem', marginTop: '1rem' }}>
            {firebaseReady ? (
              <button
                className="btn btn-gold"
                type="button"
                onClick={() => {
                  setError(null)
                  void loginGoogle().catch((err: unknown) =>
                    setError(err instanceof Error ? err.message : 'Error de Google'),
                  )
                }}
              >
                Continuar con Google
              </button>
            ) : (
              <button className="btn btn-gold" type="button" onClick={loginDemo}>
                Entrar como personal (demo Google)
              </button>
            )}
            {firebaseReady && (
              <button className="btn btn-outline" type="button" onClick={loginDemo}>
                Probar panel en modo demo
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
        <div style={{ display: 'flex', justifyContent: 'space-between', gap: '1rem', flexWrap: 'wrap' }}>
          <div>
            <h2>Panel de reservas</h2>
            <p className="muted">
              Hola, {user.displayName} · {user.email}
              {!firebaseReady ? ' · Datos locales (demo)' : ' · Firebase + Google'}
            </p>
          </div>
          <button className="btn btn-ghost" type="button" onClick={() => void logout()}>
            Cerrar sesión
          </button>
        </div>

        <div className="stats">
          <div className="stat">
            <b>{stats.total}</b>
            <span className="muted">Total</span>
          </div>
          <div className="stat">
            <b>{stats.pendiente}</b>
            <span className="muted">Pendientes</span>
          </div>
          <div className="stat">
            <b>{stats.confirmada}</b>
            <span className="muted">Confirmadas</span>
          </div>
          <div className="stat">
            <b>{stats.cancelada}</b>
            <span className="muted">Canceladas</span>
          </div>
          <div className="stat">
            <b>{stats.completada}</b>
            <span className="muted">Completadas</span>
          </div>
        </div>

        <div className="filters">
          <input
            placeholder="Buscar código, nombre, teléfono…"
            value={q}
            onChange={(e) => setQ(e.target.value)}
          />
          <select
            value={estado}
            onChange={(e) => setEstado(e.target.value as 'todos' | ReservationStatus)}
          >
            <option value="todos">Todos los estados</option>
            {Object.entries(STATUS_LABELS).map(([k, v]) => (
              <option key={k} value={k}>
                {v}
              </option>
            ))}
          </select>
          <input type="date" value={fecha} onChange={(e) => setFecha(e.target.value)} />
          {fecha && (
            <button className="btn btn-ghost" type="button" onClick={() => setFecha('')}>
              Limpiar fecha
            </button>
          )}
        </div>

        {error && <div className="alert alert-error">{error}</div>}

        <div className="table-wrap">
          <table>
            <thead>
              <tr>
                <th>Código</th>
                <th>Cliente</th>
                <th>Fecha / Hora</th>
                <th>Pers.</th>
                <th>Zona / Ocasión</th>
                <th>Estado</th>
                <th>Mesa</th>
                <th>Acciones</th>
              </tr>
            </thead>
            <tbody>
              {filtered.length === 0 && (
                <tr>
                  <td colSpan={8} className="muted">
                    No hay reservas con estos filtros.
                  </td>
                </tr>
              )}
              {filtered.map((r) => (
                <tr key={r.id}>
                  <td>
                    <b>{r.codigo}</b>
                    <div className="muted" style={{ fontSize: '0.75rem' }}>
                      {new Date(r.createdAt).toLocaleString('es-ES')}
                    </div>
                  </td>
                  <td>
                    <div>{r.nombre}</div>
                    <div className="muted">{r.telefono}</div>
                    {r.email && <div className="muted">{r.email}</div>}
                    {r.notas && (
                      <div className="muted" style={{ marginTop: 4 }}>
                        “{r.notas}”
                      </div>
                    )}
                  </td>
                  <td>
                    {r.fecha}
                    <div className="muted">{r.hora}</div>
                  </td>
                  <td>{r.personas}</td>
                  <td>
                    {labelZona(r.zona)}
                    <div className="muted">{labelOcasion(r.ocasion)}</div>
                  </td>
                  <td>
                    <span className={`badge badge-${r.estado}`}>{STATUS_LABELS[r.estado]}</span>
                  </td>
                  <td>
                    <input
                      style={{ minWidth: 90, padding: '0.4rem 0.5rem' }}
                      placeholder="Mesa"
                      defaultValue={r.mesaAsignada ?? ''}
                      onBlur={(e) => {
                        const value = e.target.value.trim()
                        if (value !== (r.mesaAsignada ?? '')) {
                          void patch(r.id, { mesaAsignada: value })
                        }
                      }}
                    />
                  </td>
                  <td>
                    <div className="row-actions">
                      {r.estado === 'pendiente' && (
                        <button
                          className="btn btn-ok"
                          type="button"
                          disabled={busyId === r.id}
                          onClick={() => void patch(r.id, { estado: 'confirmada' })}
                        >
                          Confirmar
                        </button>
                      )}
                      {r.estado !== 'cancelada' && r.estado !== 'completada' && (
                        <button
                          className="btn btn-danger"
                          type="button"
                          disabled={busyId === r.id}
                          onClick={() => void patch(r.id, { estado: 'cancelada' })}
                        >
                          Cancelar
                        </button>
                      )}
                      {r.estado === 'confirmada' && (
                        <>
                          <button
                            className="btn btn-outline"
                            type="button"
                            disabled={busyId === r.id}
                            onClick={() => void patch(r.id, { estado: 'completada' })}
                          >
                            Completada
                          </button>
                          <button
                            className="btn btn-ghost"
                            type="button"
                            disabled={busyId === r.id}
                            onClick={() => void patch(r.id, { estado: 'no_show' })}
                          >
                            No show
                          </button>
                        </>
                      )}
                      <a
                        className="btn btn-ghost"
                        href={`https://wa.me/34${r.telefono.replace(/\D/g, '').replace(/^34/, '')}?text=${encodeURIComponent(
                          `Hola ${r.nombre}, te escribimos de Casa Torino sobre tu reserva ${r.codigo} (${r.fecha} ${r.hora}).`,
                        )}`}
                        target="_blank"
                        rel="noreferrer"
                      >
                        WhatsApp
                      </a>
                    </div>
                  </td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      </section>
    </main>
  )
}
