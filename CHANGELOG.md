# Castmind V3.3.0 — Conversation Engine

## Calidad conversacional
- Historial estructurado real para MLX `ChatSession`: mensajes de usuario y asistente conservan su rol.
- El historial ya no se concatena dentro del system prompt.
- Los prompts de personaje grandes se compilan de forma determinista: el mismo personaje recibe el mismo núcleo de identidad en cada turno.
- Qwen3.5 2B reemplaza a Qwen3 1.7B como opción recomendada.
- Qwen3 4B es la opción de máxima calidad local.
- Sampling de conversación: temperatura saludable, Top-P, Top-K 20, Min-P 0, repetition/presence penalties.
- Nuevo `ResponseQualityGuard` detecta loops de tokens, fragmentos, baja diversidad, fugas meta y respuestas casi duplicadas.
- Las respuestas se validan antes de mostrarse o enviarse a TTS; una respuesta rota no entra en el historial.

## Salas
- Arquitectura multi-agente por perspectiva: para cada personaje, sus mensajes previos son `assistant`; los mensajes del usuario y de otros personajes son `user` etiquetados por hablante.
- Generación serial de un único personaje por vez.
- Anti-eco entre personajes y reintento oculto si una intervención duplica otra.

## Estabilidad
- Conserva limpieza de sesión/KV/Metal de V3.2.
- KV de 8-bit para el modelo recomendado 2B; 4-bit para 0.6B y 4B.
- Contexto y outputs continúan acotados para iPhone.
- Se conserva el composer fijo en chat/salas y el borrado de salas.
