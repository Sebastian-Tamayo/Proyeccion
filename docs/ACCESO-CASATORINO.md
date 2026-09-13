# Acceso GitHub: por qué el agente no puede subir a CasaTorinoApp

El agente Cursor autentica como `cursor[bot]` (GitHub App).  
Si **Contents** no es **Read and write** sobre `Sebastian-Tamayo/CasaTorinoApp`, el `git push` falla con **403**.

## Cómo conceder acceso (recomendado)

1. GitHub → tu foto → **Settings** → **Applications** → **Installed GitHub Apps** → **Cursor**
2. **Repository access**: All repositories (o al menos `CasaTorinoApp` + `Proyeccion`)
3. **Permissions** → **Repository permissions** → **Contents: Read and write**
4. Guarda / Accept new permissions si GitHub lo pide
5. Avisa al agente para reintentar el push

## Alternativa: push desde tu PC

```bash
curl -fsSL https://raw.githubusercontent.com/Sebastian-Tamayo/Proyeccion/main/docs/publicar-en-casatorinoapp.sh | bash
```

O clona `CasaTorinoApp`, copia el paquete `web/` + README del agente y `git push origin main`.

## URLs correctas (Vercel)

- Web: https://casa-torino-web.vercel.app  
- Reservas: https://reservas-casatorino.vercel.app  
- ERP: https://casa-torino-app.vercel.app/login  
- Netlify inauguración = archivo solamente
