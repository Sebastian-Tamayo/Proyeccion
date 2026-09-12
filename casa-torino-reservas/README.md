# Casa Torino — App de reservas

Aplicación web para **solicitar y gestionar reservas** del bar-restaurante **Casa Torino** (Gijón), con la identidad visual oficial (logo, oro/azul noche, fusión Colombo-Asturiana).

## Qué incluye

### Cliente (público)
- Formulario de reserva con:
  - Nombre, teléfono/WhatsApp, email
  - Fecha, hora, nº de personas
  - Zona preferida (interior / barra / terraza)
  - Ocasión (cumpleaños, cita, familia…)
  - Notas / alergias / peticiones
- Código de reserva automático (`CT-XXXX`)
- Enlace directo a WhatsApp del local (`612 254 719`)
- Datos del negocio: Ctra. Ceares 67, Gijón · apertura desde 12:00

### Personal (admin)
- Autenticación con **una sola plataforma: Google**
- Panel con tabla de reservas, filtros y estadísticas
- Acciones: confirmar, cancelar, marcar completada / no-show
- Asignar mesa y abrir chat WhatsApp al cliente

## Arranque rápido (modo demo, sin cuentas)

```bash
cd casa-torino-reservas
npm install
npm run dev
```

Abre la URL local:
1. En `/` pide una reserva de prueba.
2. En `/admin` pulsa **Entrar como personal (demo Google)**.

Los datos se guardan en el navegador (`localStorage`) hasta que configures Firebase.

## Producción: Google Auth + Firestore

1. Crea un proyecto en [Firebase Console](https://console.firebase.google.com/).
2. Activa **Authentication → Google**.
3. Crea Firestore (modo producción) con colección `reservas`.
4. Copia `.env.example` a `.env` y rellena las claves `VITE_FIREBASE_*`.
5. Añade los Gmail del equipo en `src/config.ts` → `ADMIN_EMAILS`.
6. Despliega en Netlify (el sitio actual es `casatorino.netlify.app`):

```bash
npm run build
# Publish directory: dist
```

`netlify.toml` ya incluye redirección SPA.

### Reglas Firestore sugeridas

```
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    match /reservas/{id} {
      allow create: if true; // solicitud pública
      allow read, update: if request.auth != null
        && request.auth.token.email in [
          'tu-gmail@gmail.com'
        ];
    }
  }
}
```

(Ajusta la lista de emails o usa Custom Claims.)

## Stack

- React + TypeScript + Vite
- React Router
- Firebase Auth (Google) + Firestore (opcional)
- Modo demo local sin backend

## Marca

Logo oficial incluido en `public/logo.jpg`.
