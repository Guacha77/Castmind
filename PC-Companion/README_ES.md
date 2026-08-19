# Castmind Stream Bridge V3

Companion local para Windows. Recibe las respuestas de Castmind por Wi‑Fi, se anuncia automáticamente mediante mDNS/Bonjour y puede actualizar OBS + reproducir TTS local.

## Instalación
1. Ejecuta `install_windows.bat`.
2. Abre `config.json` y cambia `secret` por una clave larga. Pon exactamente la misma clave en Castmind > Ajustes > Stream Bridge > Configuración manual.
3. Ejecuta `run_bridge.bat`.
4. En el iPhone activa Stream Bridge y `Descubrir PC automáticamente`.

## OBS
En OBS crea una escena `AI CAST` con:
- `Castmind - Captions` (fuente de texto)
- `Castmind - Idle`
- `Castmind - Talking`

Ve a Herramientas > WebSocket Server Settings y activa el servidor. Después edita `config.json`: `obs_enabled: true`, password y nombres si son distintos.

El companion no envía datos a Internet. El servidor WebSocket escucha en la LAN y exige la clave compartida para procesar eventos.
