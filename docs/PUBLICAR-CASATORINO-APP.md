# Publicar el ecosistema en CasaTorinoApp

## Estado

- Monorepo unificado (web + ERP + reservas + media): ya está en  
  https://github.com/Sebastian-Tamayo/Proyeccion/tree/main/casa-torino
- El repo destino https://github.com/Sebastian-Tamayo/CasaTorinoApp  
  **sigue con solo el ERP** si el push desde tu PC no terminó bien.

## Opción recomendada (1 comando en tu PC)

```bash
curl -fsSL https://raw.githubusercontent.com/Sebastian-Tamayo/Proyeccion/main/docs/publicar-casatorino-app.sh | bash
```

O descarga y ejecuta:

```bash
git clone https://github.com/Sebastian-Tamayo/Proyeccion.git
bash Proyeccion/docs/publicar-casatorino-app.sh
```

Al final debes ver en GitHub las carpetas: `web/` · `erp/` · `reservas/` · `docs/`.

## Comprobar que funcionó

Abre: https://github.com/Sebastian-Tamayo/CasaTorinoApp  

Si **no** ves `web/` y `reservas/`, el push no llegó. Pega aquí la salida del script.
