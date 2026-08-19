# Castmind V3.1 — Stability & Input Update

## Cambios principales

- Composer de Chat anclado con `safeAreaInset`: siempre visible y compatible con teclado.
- Composer de Salas anclado de la misma forma.
- Entrada por voz en Salas: el mensaje hablado se envía a todos los personajes de la sala.
- TTS en Salas en cola: cada personaje puede leer su propio turno sin cortar al anterior.
- `CREATE_BLANK` pasa a ser la opción principal/predeterminada al crear personajes.
- Los personajes blank ahora nacen realmente vacíos, sin un preset oculto.
- Nuevo `PromptBudgeter`: conserva el prompt completo en almacenamiento, pero compila una vista segura por turno cuando es enorme.
- Ranking determinista de bloques del comportamiento: prioriza identidad, reglas, prohibiciones, forma de hablar y contenido relevante para el mensaje actual.
- Preflight de tokens antes de crear el `ChatSession` para impedir contextos que excedan el margen seguro de memoria.
- Mensajes, memorias y transcript de salas limitados por bloque antes de formar el prompt.
- Generación adaptativa cuando el prompt fuente es muy grande.
- Speech.framework se drena antes de iniciar el prefill MLX; el recognition task se cancela y `AVAudioEngine` se resetea para liberar recursos rápidamente.
- Memory warning cancela tanto conversación directa como salas antes de descargar el modelo de RAM.
- Corregido un guardado duplicado de avatar.
- Launch screen simplificado al sistema moderno `UILaunchScreen`; se elimina el storyboard legacy.
- `Info.plist` es usado directamente por Xcode (`INFOPLIST_FILE`, `GENERATE_INFOPLIST_FILE=NO`).
- Versión 3.1.0, build 310.
