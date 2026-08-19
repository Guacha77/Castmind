# Castmind V3.1 — Arquitectura

## Principios

1. **Un modelo global** en RAM.
2. **Muchos personajes**, cada uno con `behaviorPrompt`, parámetros, voz y memoria independientes.
3. El prompt de comportamiento es la autoridad principal del personaje.
4. El prompt fuente se conserva íntegro, pero la inferencia usa una ventana acotada y segura.
5. El contexto dinámico se mantiene pequeño y factual.
6. La UI no debe realizar trabajo continuo cuando está en reposo.

## Flujo de chat

`input → PromptBudgeter → memoria relevante → strict system prompt → token preflight → MLX stream → UI throttled → ReplySanitizer → persistencia → TTS`

`PromptBudgeter` evita que un personaje importado o un prompt enorme pueda crear contexto sin límite. Para prompts grandes, selecciona bloques con prioridad por reglas/identidad y relevancia al mensaje. Antes de crear la sesión, `AIEngine` cuenta tokens y rechaza de forma controlada cualquier contexto que siga superando el techo seguro.

## Voz

`Speech.framework → transcript → stop/cancel recognizer → reset AVAudioEngine → breve drain → PromptBudgeter → MLX`

La separación entre STT y prefill MLX reduce el pico de recursos al responder por voz.

## Salas

Cada participante recibe una inferencia separada. La transcripción incluye etiquetas de autores, pero el contrato exige una sola intervención del `PERSONAJE ASIGNADO`. Solo tras sanitizar se añade esa respuesta a la sala. Nunca se publica el stream bruto del modelo en la sala.

La entrada por voz de una sala produce un único mensaje del usuario que se entrega al round completo. Las respuestas con TTS activo se encolan por personaje para que una no corte a la anterior.

## Persistencia

La estructura V2/V3 de biblioteca se conserva para que una actualización no pierda datos. `CharacterProfile.behaviorPrompt` es opcional en Codable para poder abrir personajes antiguos; un `CREATE_BLANK` nuevo usa cadena vacía de forma intencional y no se rellena con un preset oculto.

## Estabilidad

- 1.7B como default.
- Límites térmicos en `PerformanceManager`.
- Prompt/KV context acotado antes de inferencia.
- `NSCache` para avatares.
- Memory warning → cancelar chat/sala/voz → unload MLX.
- `activeSession` de MLX liberada después de cada turno.
- Modelo global evita churn de RAM al cambiar de personaje.
- Speech recognizer y audio engine se liberan antes del prefill.

## Full-screen

Castmind usa el mecanismo moderno `UILaunchScreen` con `LaunchBackground` y `UIRequiresFullScreen=true`, sin storyboard legacy. El target usa directamente `Castmind/Resources/Info.plist` mediante `INFOPLIST_FILE` y `GENERATE_INFOPLIST_FILE=NO`. CI inspecciona el `Info.plist` construido y el IPA final.
