# Casa Torino — Reservas LOCALES (4 personas)

Aplicación **solo local** para el personal del bar.
No se publica en internet.

## Personal (4)
| Persona  | PIN |
|----------|-----|
| Lorena   | 1234 |
| Yuli     | 1234 |
| Dayana   | 1234 |
| Claribel | 1234 |

Cambia los PIN en `server/staff.json`.

## Cómo usarla en el bar

En el **PC del bar** (conectado al WiFi del local):

```bash
cd casa-torino-reservas
npm install
npm run start
```

La terminal mostrará algo así:
- PC: `http://127.0.0.1:8787`
- Móvil: `http://192.168.x.x:8787` (misma WiFi)

Los 4 móviles abren esa IP. Todos ven las mismas reservas
(guardadas en `data/reservas.json`).

## Campos (rápidos)
Nombre · Teléfono (opc.) · Personas · Día · Hora · Nota (opc.)

## Desarrollo
```bash
npm run local   # API + dist en :8787
npm run dev     # API + Vite a la vez
```
