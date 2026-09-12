# Deploy — Casa Torino Reservas (Vercel)

Netlify ya no acepta deploys (créditos agotados). Producción va en **Vercel**.

## URL actual (deploy anónimo)

- App: https://temporary-zippy-poplar-0bmrs89.vercel.app  
- Claim (permanente): https://vercel.com/claim-deployment?code=2328de0e-4efd-4fea-b4bc-e3729476e34f  

El deploy anónimo **caduca en ~60 minutos** si no se reclama o no hay `vercel login` + `--prod`.

## Una vez (login)

```bash
cd casa-torino-reservas
npx vercel login
```

Abre el enlace device que imprime la CLI y confirma en el navegador.

## Producción permanente

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
