# Casa Torino — Reservas LOCALES (4 personas)

App **solo local**, sin publicar en internet. Pensada para el personal del bar
cuando un cliente se acerca a reservar.

## Personal (4)
| Persona   | PIN por defecto |
|-----------|-----------------|
| Lorena    | 1234            |
| Yuli      | 1234            |
| Dayana    | 1234            |
| Claribel  | 1234            |

Cambia los PIN en `server/staff.json`.

## Arranque en el PC del bar

```bash
cd casa-torino-reservas
npm install
npm run build
npm run local
```

En la terminal verás:
- `http://127.0.0.1:8787` (el PC)
- `http://192.168.x.x:8787` (móviles en la **misma WiFi**)

Los 4 móviles/tablets usan esa IP. Los datos se guardan en `data/reservas.json` (compartidos).

## Desarrollo

```bash
# terminal 1
npm run local

# terminal 2
npm run dev
```

## Campos rápidos
Nombre · Teléfono (opc.) · Personas · Día · Hora · Nota (opc.)
