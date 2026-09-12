import { useMemo, useState, type FormEvent } from 'react'
import { BUSINESS, HORAS_RESERVA, OCASIONES, ZONAS } from '../config'
import { createReservation } from '../lib/reservations'
import type { Ocasion, ZonaPreferida } from '../types'

function todayISO() {
  const d = new Date()
  const off = d.getTimezoneOffset()
  const local = new Date(d.getTime() - off * 60_000)
  return local.toISOString().slice(0, 10)
}

function maxDateISO() {
  const d = new Date()
  d.setDate(d.getDate() + BUSINESS.maxDaysAhead)
  const off = d.getTimezoneOffset()
  const local = new Date(d.getTime() - off * 60_000)
  return local.toISOString().slice(0, 10)
}

export function HomePage() {
  const [nombre, setNombre] = useState('')
  const [telefono, setTelefono] = useState('')
  const [email, setEmail] = useState('')
  const [fecha, setFecha] = useState(todayISO())
  const [hora, setHora] = useState('14:00')
  const [personas, setPersonas] = useState(2)
  const [zona, setZona] = useState<ZonaPreferida>('sin_preferencia')
  const [ocasion, setOcasion] = useState<Ocasion>('ninguna')
  const [notas, setNotas] = useState('')
  const [submitting, setSubmitting] = useState(false)
  const [error, setError] = useState<string | null>(null)
  const [codigo, setCodigo] = useState<string | null>(null)

  const whatsappHref = useMemo(() => {
    const text = encodeURIComponent(
      `Hola Casa Torino, quiero consultar una reserva. Nombre: ${nombre || '—'}. Fecha: ${fecha} ${hora}.`,
    )
    return `https://wa.me/${BUSINESS.whatsapp}?text=${text}`
  }, [nombre, fecha, hora])

  async function onSubmit(e: FormEvent) {
    e.preventDefault()
    setError(null)
    setCodigo(null)

    if (!nombre.trim() || !telefono.trim()) {
      setError('Nombre y teléfono son obligatorios.')
      return
    }
    if (personas < BUSINESS.minPartySize || personas > BUSINESS.maxPartySize) {
      setError(`El número de personas debe estar entre ${BUSINESS.minPartySize} y ${BUSINESS.maxPartySize}.`)
      return
    }

    setSubmitting(true)
    try {
      const reservation = await createReservation({
        nombre: nombre.trim(),
        telefono: telefono.trim(),
        email: email.trim(),
        fecha,
        hora,
        personas,
        zona,
        ocasion,
        notas: notas.trim(),
      })
      setCodigo(reservation.codigo)
      setNotas('')
    } catch (err) {
      setError(err instanceof Error ? err.message : 'No se pudo enviar la reserva.')
    } finally {
      setSubmitting(false)
    }
  }

  return (
    <main className="page">
      <section className="hero">
        <div className="hero-copy">
          <div className="fusion-badge">🍴 {BUSINESS.tagline}</div>
          <h1>{BUSINESS.name}</h1>
          <p className="slogan">“{BUSINESS.slogan}”</p>
          <p className="muted">
            Solicita tu mesa en nuestro bar-restaurante de Gijón. Te confirmaremos la reserva lo antes
            posible por teléfono o WhatsApp.
          </p>
          <div style={{ display: 'flex', gap: '0.6rem', flexWrap: 'wrap', marginTop: '1rem' }}>
            <a className="btn btn-gold" href="#reservar">
              Pedir reserva
            </a>
            <a className="btn btn-outline" href={whatsappHref} target="_blank" rel="noreferrer">
              WhatsApp {BUSINESS.phone}
            </a>
          </div>
        </div>
        <div className="hero-logo-wrap">
          <img src="/logo.jpg" alt="Emblema oficial Casa Torino" />
        </div>
      </section>

      <section className="info-strip">
        <div className="info-item">
          <strong>📍 Ubicación</strong>
          <span>{BUSINESS.address}</span>
        </div>
        <div className="info-item">
          <strong>🕒 Horario</strong>
          <span>
            Apertura desde las {BUSINESS.openFrom} · Última reserva {BUSINESS.lastReservation}
          </span>
        </div>
        <div className="info-item">
          <strong>📞 Contacto</strong>
          <span>Móvil / WhatsApp: {BUSINESS.phone}</span>
        </div>
      </section>

      <section className="card" id="reservar">
        <h2>Solicitar reserva</h2>
        <p className="muted">
          Completa el formulario. La solicitud queda en estado <b>pendiente</b> hasta que el personal la
          confirme.
        </p>

        {codigo && (
          <div className="alert alert-ok">
            ¡Reserva recibida! Tu código es <div className="success-code">{codigo}</div>
            Guárdalo. También puedes escribirnos por WhatsApp mencionando ese código.
          </div>
        )}
        {error && <div className="alert alert-error">{error}</div>}

        <form className="grid-form two" onSubmit={onSubmit}>
          <label>
            Nombre completo *
            <input
              required
              value={nombre}
              onChange={(e) => setNombre(e.target.value)}
              placeholder="Ej. Ana Pérez"
              autoComplete="name"
            />
          </label>
          <label>
            Teléfono / WhatsApp *
            <input
              required
              value={telefono}
              onChange={(e) => setTelefono(e.target.value)}
              placeholder="612 254 719"
              inputMode="tel"
              autoComplete="tel"
            />
          </label>
          <label>
            Email
            <input
              type="email"
              value={email}
              onChange={(e) => setEmail(e.target.value)}
              placeholder="opcional@email.com"
              autoComplete="email"
            />
          </label>
          <label>
            Nº de personas *
            <input
              type="number"
              min={BUSINESS.minPartySize}
              max={BUSINESS.maxPartySize}
              value={personas}
              onChange={(e) => setPersonas(Number(e.target.value))}
              required
            />
          </label>
          <label>
            Fecha *
            <input
              type="date"
              required
              min={todayISO()}
              max={maxDateISO()}
              value={fecha}
              onChange={(e) => setFecha(e.target.value)}
            />
          </label>
          <label>
            Hora *
            <select value={hora} onChange={(e) => setHora(e.target.value)} required>
              {HORAS_RESERVA.map((h) => (
                <option key={h} value={h}>
                  {h}
                </option>
              ))}
            </select>
          </label>
          <label>
            Zona preferida
            <select value={zona} onChange={(e) => setZona(e.target.value as ZonaPreferida)}>
              {ZONAS.map((z) => (
                <option key={z.value} value={z.value}>
                  {z.label}
                </option>
              ))}
            </select>
          </label>
          <label>
            Ocasión
            <select value={ocasion} onChange={(e) => setOcasion(e.target.value as Ocasion)}>
              {OCASIONES.map((o) => (
                <option key={o.value} value={o.value}>
                  {o.label}
                </option>
              ))}
            </select>
          </label>
          <label className="full">
            Notas o peticiones especiales
            <textarea
              value={notas}
              onChange={(e) => setNotas(e.target.value)}
              placeholder="Alergias, trona, accesibilidad, celebración…"
              maxLength={500}
            />
          </label>
          <div className="full" style={{ display: 'flex', gap: '0.75rem', flexWrap: 'wrap' }}>
            <button className="btn btn-gold" type="submit" disabled={submitting}>
              {submitting ? 'Enviando…' : 'Enviar solicitud'}
            </button>
            <span className="muted" style={{ alignSelf: 'center', fontSize: '0.85rem' }}>
              Máx. {BUSINESS.maxPartySize} personas · Grupos mayores: llámanos o WhatsApp.
            </span>
          </div>
        </form>
      </section>

      <footer className="footer">
        <p>
          {BUSINESS.name} · {BUSINESS.address} · {BUSINESS.phone}
        </p>
        <p>Fusión Colombo-Asturiana · Sabor que deja huella</p>
      </footer>
    </main>
  )
}
