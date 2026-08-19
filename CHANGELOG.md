# Castmind 2.0.0

## Núcleo
- Modelo compartido entre personajes y auto-carga al iniciar/volver a primer plano.
- Perfiles Rápido / Equilibrado / Calidad.
- Perfil Equilibrado: `mlx-community/Qwen3.5-2B-4bit`.
- Warm-up opcional, benchmark local y adaptación térmica.
- Streaming visible desde el primer texto útil; se filtran bloques `<think>`.
- Cancelación de generación y métricas TTFT/tokens aproximados por segundo.

## Personajes
- Biblioteca multi-personaje.
- Avatar desde Fotos y animación reactiva a voz/micrófono.
- Personalidad, rol, saludo, reglas, wake word y color independientes.
- Temperatura, top-p, tokens, contexto y modelo preferido por personaje.
- Voz, velocidad, tono y volumen por personaje.
- Duplicar / importar / exportar personaje.

## Conversación
- Teclado descartable por swipe, toque y botón `Cerrar`.
- Historial por personaje, búsqueda, pin, borrado y nuevas conversaciones.
- Regenerar / copiar / borrar / reproducir respuestas.
- Swipe izquierdo en respuesta para `Por qué respondió así`: resumen observable, no chain-of-thought oculto.
- TTS por frases mientras la respuesta todavía se genera.
- Interrupción inmediata al volver a hablar.

## Memoria y estado
- Memoria aislada y activable por personaje.
- Captura automática opcional, categorías, importancia, pin, búsqueda y edición.
- Selección por relevancia y decay/olvido inteligente.
- Estados: ira, confianza, energía, humor, estrés, entusiasmo y afecto.
- Migración de datos básicos desde Castmind V1.

## Multi-IA / stream
- Salas de hasta cuatro personajes con turnos automáticos.
- Modo Stream a pantalla completa.
- Push-to-talk y manos libres con detección de silencio.
- Wake words para enrutar la voz al personaje correcto.
- Escenarios Normal / Just Chatting / Gaming / IRL.
- Stream Bridge V2 con descubrimiento mDNS, companion Windows, dashboard, OBS y TTS local.

## Datos / calidad
- Backup completo e importación.
- Estadísticas locales y HUD opcional.
- Sin analytics, cuentas, OpenAI ni ElevenLabs.
- Workflow macOS-26 con validación del bundle y del IPA antes de subir artifact.
