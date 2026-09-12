# Acceso GitHub: por qué el agente no puede subir a CasaTorinoApp

La instalación de Cursor **en este entorno cloud** solo lista:

- `Sebastian-Tamayo/Proyeccion`

Aunque en la UI añadas `CasaTorinoApp` y `casa-torino-web`, el token del agente sigue limitado a Proyeccion (403 al hacer push).

## Publicar el ecosistema en CasaTorinoApp (tu PC)

```bash
curl -fsSL https://raw.githubusercontent.com/Sebastian-Tamayo/Proyeccion/main/docs/publicar-en-casatorinoapp.sh | bash
```

Eso deja en https://github.com/Sebastian-Tamayo/CasaTorinoApp las carpetas:

- `web/`
- `erp/`
- `reservas/`
- `docs/`
