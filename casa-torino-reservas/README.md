# Casa Torino — Reservas internas (rápidas)

Herramienta para el **personal** del bar: cuando un cliente se acerca a reservar, se anota en segundos.

## Campos (mínimos)
- Nombre *
- Teléfono (opcional)
- Personas (botones 1–8 / 9+)
- Día + Hora
- Nota (opcional)

La reserva se guarda ya **confirmada**. Debajo ves la lista del día (Hecha / No vino / Anular / WhatsApp).

## Uso local
```bash
cd casa-torino-reservas
npm install
npm run dev
```
Entra con **Entrar** (demo) o Google si configuras Firebase.

## Auth
Una sola plataforma: **Google** (opcional). Sin claves → modo demo local.

Copia `.env.example` → `.env` y añade los Gmail del equipo en `src/config.ts` (`ADMIN_EMAILS`).

## Deploy Netlify
`npm run build` · publish `dist` · `netlify.toml` incluido.
