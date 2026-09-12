import { BrowserRouter, Navigate, Route, Routes } from 'react-router-dom'
import { AuthProvider } from './auth'
import { Topbar } from './components/Topbar'
import { AdminPage } from './pages/AdminPage'
import { HomePage } from './pages/HomePage'

export default function App() {
  return (
    <AuthProvider>
      <BrowserRouter>
        <Topbar />
        <Routes>
          <Route path="/" element={<HomePage />} />
          <Route path="/admin" element={<AdminPage />} />
          <Route path="*" element={<Navigate to="/" replace />} />
        </Routes>
      </BrowserRouter>
    </AuthProvider>
  )
}
