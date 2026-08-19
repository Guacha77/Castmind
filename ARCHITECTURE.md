# Castmind V2 — Arquitectura

## Principios
- **Un modelo en RAM, muchos personajes**: `AIEngine` mantiene un único `ModelContainer`; personalidad, memoria y parámetros viven fuera del modelo.
- **Datos aislados por personaje**: cada `CharacterProfile` tiene configuración, voz, estado, relaciones y memorias propias.
- **Offline-first**: inferencia, STT, TTS, memoria y UI funcionan localmente. La red solo se usa para descargar pesos y para Stream Bridge si se activa.
- **UI reactiva, núcleo pequeño**: `AppState` orquesta; servicios especializados hacen IA, persistencia, audio, memoria, rendimiento y bridge.
- **Fallos recuperables**: generación cancelable, persistencia atómica, backups, migración V1 y validación estricta del IPA.

## Flujo de una respuesta
```text
Usuario (texto / micrófono)
  → routing por wake word (opcional)
  → memoria relevante + estado + escenario + contexto reciente
  → AIEngine / MLX (streaming)
  → filtro <think> → burbuja visible desde el primer texto útil
  → TTS por frases en paralelo (opcional)
  → persistencia + métricas + Stream Bridge (opcional)
```

## Capas
- `Models/Domain.swift`: modelos de dominio y configuración.
- `Core/AIEngine.swift`: carga, warm-up, streaming, benchmark y caché del modelo.
- `Core/AppState.swift`: orquestación principal, multi-personaje, chat, salas, import/export.
- `Core/PersistenceStore.swift`: biblioteca V2, avatars, backups y migración V1.
- `Core/MemoryEngine.swift`: captura heurística, ranking por relevancia y decay.
- `Core/StateAnalyzer.swift`: cambios emocionales locales sin llamada extra al LLM.
- `Core/SpeechServices.swift`: STT on-device y TTS local con streaming por frases.
- `Core/PerformanceManager.swift`: perfiles de rendimiento y adaptación térmica.
- `Core/StreamBridgeService.swift`: WebSocket + descubrimiento Bonjour/mDNS.
- `Views/`: interfaz SwiftUI.
- `PC-Companion/`: dashboard Windows, mDNS, WebSocket, OBS y TTS local.

## Persistencia
V2 guarda `library-v2.json`, `settings-v2.json` y avatares bajo `Application Support/CastmindV2`. Los JSON de V2 usan fechas ISO-8601 y escrituras atómicas.

En el primer arranque, si no existe biblioteca V2, se buscan los archivos reales de V1 en Documents:
- `castmind-profile.json`
- `castmind-messages.json`
- `castmind-generation.json`

La migración conserva perfil, conversación, memoria textual, voz, parámetros, onboarding y datos básicos del bridge.

## Seguridad del Stream Bridge
El bridge solo se activa si el usuario lo habilita. Los eventos incluyen una clave compartida local; el companion rechaza mensajes con una clave distinta. No se ejecutan comandos arbitrarios recibidos del modelo.

## Pensamiento / explicaciones
Castmind nunca intenta exponer chain-of-thought privado. Los bloques `<think>` se eliminan de la salida visible. El gesto lateral de una respuesta genera, bajo demanda, un resumen breve de factores observables (mensaje, personalidad, memoria y estado).
