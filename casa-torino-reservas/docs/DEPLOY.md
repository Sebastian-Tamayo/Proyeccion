# Deploy — Casa Torino Reservas (Vercel)

Netlify ya no acepta deploys (créditos agotados). Producción va en **Vercel**.

## Una vez (login)

```bash
cd casa-torino-reservas
npx vercel login
```

Abre el enlace device que imprime la CLI y confirma en el navegador.

## Producción

```bash
cd casa-torino-reservas
npm run build
npx vercel --prod
```

Root del proyecto en Vercel: carpeta `casa-torino-reservas` (no la raíz del monorepo).

## Variables opcionales

| Variable | Uso |
|----------|-----|
| `RESERVAS_STORE_URL` | Endpoint del store JSON (por defecto CrudCrud en código) |

## PIN demo

Personal: Lorena / Yuli / Dayana / Claribel — PIN `1234` (`src/config.ts`).
