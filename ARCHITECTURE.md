# Castmind V3 — Arquitectura

## Principios

1. **Un modelo global** en RAM.
2. **Muchos personajes**, cada uno con `behaviorPrompt`, parámetros, voz y memoria independientes.
3. El prompt de comportamiento es la única autoridad de personalidad.
4. El contexto dinámico se mantiene pequeño y factual.
5. La UI no debe realizar trabajo continuo cuando está en reposo.

## Flujo de chat

`input → memoria relevante → strict system prompt → MLX stream → UI throttled → ReplySanitizer → persistencia → TTS final`

`ReplySanitizer` es una capa defensiva; la primera defensa sigue siendo el contrato del prompt.

## Salas

Cada participante recibe una inferencia separada. La transcripción incluye etiquetas de autores, pero el contrato exige una sola intervención del `PERSONAJE ASIGNADO`. Solo tras sanitizar se añade esa respuesta a la sala. Nunca se publica el stream bruto del modelo en la sala.

## Persistencia

La estructura V2 de biblioteca se conserva para que una actualización no pierda datos. `CharacterProfile.behaviorPrompt` es opcional en Codable para poder abrir personajes antiguos; `effectiveBehavior` migra de forma lógica los campos legacy cuando sea necesario.

## Estabilidad

- 1.7B como default.
- Límites térmicos en `PerformanceManager`.
- `NSCache` para avatares.
- Memory warning → cancelar voz/generación → unload MLX.
- `activeSession` de MLX liberada después de cada turno.
- Modelo global evita churn de RAM al cambiar de personaje.

## Full-screen

El target contiene configuración launch moderna y storyboard. CI inspecciona el `Info.plist` **construido**, no solo el fuente, y comprueba que el storyboard compilado existe dentro de `Castmind.app`.
