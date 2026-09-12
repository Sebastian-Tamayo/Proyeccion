import { NavLink } from 'react-router-dom'
import { BUSINESS } from '../config'
import { useAuth } from '../auth'

export function Topbar() {
  const { user, logout } = useAuth()

  return (
    <header className="topbar page" style={{ width: 'min(1100px, 100% - 2rem)', marginBottom: 0 }}>
      <NavLink to="/" className="brand">
        <img src="/logo.jpg" alt="Logo Casa Torino" />
        <div>
          <strong>{BUSINESS.name}</strong>
          <span>{BUSINESS.slogan}</span>
        </div>
      </NavLink>

      <div className="nav-actions">
        <span className="pill" title="Orígenes de la casa">
          🇨🇴 Colombia · 🇪🇸 España
        </span>
        <NavLink className="btn btn-ghost" to="/">
          Reservar
        </NavLink>
        {user?.isAdmin ? (
          <>
            <NavLink className="btn btn-outline" to="/admin">
              Panel
            </NavLink>
            <button className="btn btn-ghost" type="button" onClick={() => void logout()}>
              Salir
            </button>
          </>
        ) : (
          <NavLink className="btn btn-outline" to="/admin">
            Personal
          </NavLink>
        )}
      </div>
    </header>
  )
}
