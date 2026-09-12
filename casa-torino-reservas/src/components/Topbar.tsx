import { useAuth } from '../auth'
import { BUSINESS } from '../config'

export function Topbar() {
  const { user, logout } = useAuth()

  return (
    <header className="topbar">
      <div className="brand">
        <img src="/logo.jpg" alt="Casa Torino" />
        <div>
          <strong>{BUSINESS.name}</strong>
          <span>Reservas internas</span>
        </div>
      </div>
      {user?.isAdmin && (
        <button className="btn btn-ghost" type="button" onClick={() => void logout()}>
          Salir
        </button>
      )}
    </header>
  )
}
