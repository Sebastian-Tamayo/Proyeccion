# Todo debe ir a CasaTorinoApp (no a Proyeccion)

## Bloqueo actual

Este agente **no puede escribir** en  
https://github.com/Sebastian-Tamayo/CasaTorinoApp  
(error **403**: el token de Cursor solo tiene permiso de push en `Proyeccion`).

Hasta que des permiso o lo subas tú, el monorepo unificado solo está de tránsito en:
https://github.com/Sebastian-Tamayo/Proyeccion/tree/main/casa-torino

Cuando esté en `CasaTorinoApp`, se puede borrar esa carpeta de `Proyeccion`.

---

## Opción A (recomendada): dar acceso a Cursor y yo lo subo

1. Abre: https://github.com/settings/installations  
2. Entra en la app **Cursor** (o “Cursor Agent” / GitHub App de Cursor)  
3. **Repository access** → **Only select repositories**  
4. Añade **`CasaTorinoApp`** (y guarda)  
5. Escribe aquí: **`listo, ya te di acceso`**

Yo haré el push completo a `CasaTorinoApp` y limpiaré `Proyeccion`.

---

## Opción B: tú lo publicas en 1 comando (tu PC)

```bash
curl -fsSL https://raw.githubusercontent.com/Sebastian-Tamayo/Proyeccion/main/docs/publicar-casatorino-app.sh | bash
```

Luego comprueba que en  
https://github.com/Sebastian-Tamayo/CasaTorinoApp  
aparecen las carpetas **`web/` · `erp/` · `reservas/` · `docs/`**.

Si no aparecen, el comando falló: pega la salida completa.
