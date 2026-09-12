# Arquitectura — Reservas Casa Torino

## Diagrama lógico

```text
[Móvil personal]
      │ HTTPS
      ▼
[SPA React (Netlify CDN)]
      │ /api/reservas
      ▼
[Netlify Functions]
      │
      ▼
[Netlify Blobs]  ← persistencia JSON de reservas
```

## Endpoints
| Método | Ruta | Descripción |
|--------|------|-------------|
| `GET` | `/api/reservas` | Listado |
| `POST` | `/api/reservas` | Alta |
| `PUT` | `/api/reservas/:id` | Edición / cambio de estado |

## Frontend
- `StaffPage`: login + formulario + listado + edición inline  
- `config.ts`: datos de negocio, personal y PIN  
- `lib/api.ts`: cliente tipado

## Seguridad (nivel negocio pequeño)
- Auth por PIN en cliente (suficiente para uso interno controlado)  
- Sin datos de pago  
- Credenciales demo documentadas; PIN real debe rotarse

## Deploy
- Build: `npm run build` → `dist/`  
- Hosting + functions: Netlify (`netlify.toml`)  
- URL prod: https://reservas-casatorino.netlify.app
