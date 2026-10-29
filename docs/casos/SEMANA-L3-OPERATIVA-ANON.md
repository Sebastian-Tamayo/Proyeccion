# Caso portfolio: semana operativa L3 (versión anonimizada)

**Autor:** Sebastián Olaya Tamayo  
**Uso:** GitHub / reclutadores. **Sin** dominios, DC, IPs, shares ni nombres de campaña reales.

> La telemetría real vive solo en el PC (`inbox/resumen_diario.md` + `docs/Documentacion Agente/`), fuera de Git.

## Problemas de la semana (genéricos)

| Tema | Hallazgo | Enfoque |
|------|----------|---------|
| Contingencia SaaS ITSM | Portal cloud caído | Monitor TCP 443 + protocolo offline en share interno + EDR-aware |
| Broker MFA / privilegios | Agente SYSTEM vs AppLocker | Install silenciosa; secretos en memoria, no en disco |
| VPN “Reconectando” + SBL | Fallo masivo a un concentrador | Purga perfiles XML + auditoría L4 (DTLS/UDP vs corte físico vs pool) |
| Tarea apagado / DST | `schtasks` anclado a UTC | PowerShell `ScheduledTasks` + disparador **LocalTime** |
| Citrix + contact-center cloud | Audio/WebRTC | **BCR_Client** obligatorio; no ciclar 40 min de reinstall si basta forceinstall+BCR |

## Lecciones (perfil L3 → automatización)

1. **Root cause antes que reinstalar** (BCR vs desinstalar Citrix completo).
2. **Criterio de éxito medible** (plugin BCR presente; Media Helper con BCR).
3. **Imagen base ≠ campaña** (pins de versión por cola; no dominio al sysprep).
4. **Separar datos de sitio del repo** (gitignore de inbox y docs de telemetría).

## Artefactos públicos relacionados

- [`SANTANDER-EMPRESAS.md`](SANTANDER-EMPRESAS.md) — BCR / Genesys  
- [`SANTANDER-SACE.md`](SANTANDER-SACE.md) — suite legacy  
- Scripts en `scripts/` (sin payloads ni PKI del banco)

## Qué no está en este repo (a propósito)

Inventario de firewalls/switches, FQDN de DC/VPN, OU de clientes, rutas UNC, API keys.
