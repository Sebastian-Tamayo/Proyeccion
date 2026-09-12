# Casa Torino — Reservas (extensión operativa)

> **Caso real · negocio familiar · Gijón**  
> Módulo de reservas para el personal de **Casa Torino**, pensado como **extensión** de la web pública ya publicada y del ERP / operativa interna del negocio.

[![Live](https://img.shields.io/badge/demo-reservas--casatorino.netlify.app-00C7B7?logo=netlify&logoColor=white)](https://reservas-casatorino.netlify.app)
[![Stack](https://img.shields.io/badge/stack-React%20%7C%20TypeScript%20%7C%20Vite%20%7C%20Netlify-111827)](#stack-técnico)
[![Status](https://img.shields.io/badge/estado-en%20producción-22c55e)](https://reservas-casatorino.netlify.app)

---

## Contexto del negocio

**Casa Torino** es un bar-restaurante familiar de **fusión Colombo-Asturiana** en Gijón (`Ctra. Ceares, 67`).

Ya existían:

| Pieza | Rol |
|--------|-----|
| **Web pública** | Landing / marca / inauguración → [casatorino.netlify.app](https://casatorino.netlify.app) |
| **ERP / operativa familiar** | Gestión interna del negocio (stock, caja, procesos del día a día) |

Este proyecto **no sustituye** esas piezas: las **complementa**.

### Problema real
Cuando un cliente se acerca a reservar, el personal necesita anotar la mesa **en segundos**, desde el móvil, sin fricción, y que las **4 personas del equipo** vean lo mismo al instante.

### Solución
App web **mobile-first** para el personal:

- Alta rápida de reserva  
- Edición (hora, personas, datos…)  
- Lista del día / todas con fecha visible  
- Estados: confirmada · hecha · no vino · anulada  
- Acceso simple por nombre + PIN (sin cuentas complejas)

**Demo en producción:** https://reservas-casatorino.netlify.app  

> PIN de demostración del equipo: `1234` (cambiar en producción vía `src/config.ts`).

---

## Encaje en el ecosistema Casa Torino

```text
                    CLIENTES
                       │
                       ▼
        ┌──────────────────────────┐
        │  Web pública (Netlify)   │  Marca, carta, historia, contacto
        │  casatorino.netlify.app  │
        └────────────┬─────────────┘
                     │  canal / demanda
                     ▼
        ┌──────────────────────────┐
        │  Reservas (este repo)    │  Captura operativa en sala
        │  reservas-casatorino…    │  Móvil del personal
        └────────────┬─────────────┘
                     │  datos de ocupación / servicio
                     ▼
        ┌──────────────────────────┐
        │  ERP familiar existente  │  Operativa, control interno,
        │  (negocio)               │  continuidad del día a día
        └──────────────────────────┘
```

**Para reclutadores:** es un ejemplo de producto **pequeño, desplegado y usado de verdad**, uniendo UX simple + API serverless + necesidad de negocio familiar.

---

## Capturas / vídeo (pendiente)

Las capturas y GIFs se añadirán aquí:

| Media | Descripción | Archivo |
|--------|-------------|---------|
| Login personal | Selector de persona + PIN | `docs/assets/01-login.png` *(próximamente)* |
| Alta rápida | Formulario móvil | `docs/assets/02-nueva-reserva.png` *(próximamente)* |
| Lista “Todas” | Fecha + hora visibles | `docs/assets/03-lista-todas.png` *(próximamente)* |
| Edición | Cambio de hora / personas | `docs/assets/04-editar.gif` *(próximamente)* |

Plantilla y naming: [`docs/MEDIA.md`](docs/MEDIA.md).

<!-- Ejemplo cuando existan:
![Login](docs/assets/01-login.png)
-->

---

## Funcionalidades

- [x] Login local del personal (4 perfiles + PIN)
- [x] Crear reserva (nombre, teléfono opcional, personas, día, hora, nota)
- [x] Editar reserva existente
- [x] Ver hoy / ver todas (con **fecha visible** en listado)
- [x] Cambiar estado (Hecha / No vino / Anular)
- [x] Acceso WhatsApp al teléfono del cliente
- [x] API serverless + almacenamiento en Netlify Blobs
- [x] Deploy en Netlify (producción)

---

## Stack técnico

| Capa | Tecnología |
|------|------------|
| UI | React 19 + TypeScript + Vite |
| Estilos | CSS propio (mobile-first, identidad Casa Torino) |
| Routing | React Router |
| API | Netlify Functions (`/api/reservas`) |
| Persistencia | Netlify Blobs |
| Hosting | Netlify |
| Auth personal | PIN por perfil (sin OAuth, a propósito: simplicidad en sala) |

---

## Estructura del proyecto

```text
casa-torino-reservas/
├── docs/                  # Producto, arquitectura, media
├── netlify/functions/     # API (listado, alta, edición)
├── public/                # Logo y estáticos
├── src/
│   ├── components/        # Topbar
│   ├── lib/api.ts         # Cliente HTTP
│   ├── pages/StaffPage.tsx
│   ├── config.ts          # Negocio + personal + PIN
│   └── ...
├── netlify.toml
└── README.md              # Este documento
```

Más detalle: [`docs/ARQUITECTURA.md`](docs/ARQUITECTURA.md) · [`docs/PRODUCTO.md`](docs/PRODUCTO.md)

---

## Cómo ejecutarlo en local

```bash
cd casa-torino-reservas
npm install
npm run build
# Para UI local (la API de producción sigue en Netlify):
npm run preview
```

Desarrollo con Vite:

```bash
npm run dev
```

> En local, `src/config.ts` apunta a la API de producción en Netlify para no depender de funciones locales. Para API 100% local, se puede volver a `/api/reservas` + `netlify dev`.

---

## Decisiones de diseño (resumen)

1. **Personal primero, no cliente final** → reduce pasos en el momento de la reserva presencial.  
2. **PIN simple vs Google Auth** → prioridad a velocidad en barra/sala.  
3. **Serverless + Blobs** → sin servidor que mantener para un negocio pequeño.  
4. **Extensión, no monolito** → respeta web pública y ERP ya existentes.

---

## Autor

**Sebastián Olaya Tamayo** — caso dentro del monorepo [`Proyeccion`](https://github.com/Sebastian-Tamayo/Proyeccion): transición L3 → DevOps/Cloud → producto/negocio.

---

## Licencia / uso

Proyecto de portfolio y uso interno del negocio familiar Casa Torino.  
No redistribuir credenciales de producción.
