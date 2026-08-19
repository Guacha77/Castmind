# Castmind V3.1

Castmind es una app iOS local para crear y conversar con personajes IA independientes. El modelo, memoria, voz y datos funcionan en el iPhone; no necesita OpenAI ni ElevenLabs.

## V3.1

Esta revisión está centrada en estabilidad real en iPhone:

- Chat y salas con barra de escritura persistente.
- Voz en chat y salas.
- Create Blank como flujo principal.
- Prompts de comportamiento muy grandes con ventana de inferencia segura.
- Preflight de tokens antes de MLX para evitar presión de memoria no acotada.
- TTS en cola en salas.
- Menos solapamiento de Speech.framework + MLX al responder por voz.
- Full-screen/launch moderno sin storyboard legacy.

El prompt completo de cada personaje se conserva. Si supera la ventana segura configurada para el modelo, Castmind selecciona de forma determinista los bloques más importantes/relevantes para el turno y limita además historial/memorias antes de construir el contexto.

## Modelo

- Rápido: Qwen3 0.6B 4-bit
- Equilibrado (default): Qwen3 1.7B 4-bit
- Calidad: Qwen3.5 2B 4-bit

## Instalación

Lee `INSTALL_V3_1_ES.md`.
