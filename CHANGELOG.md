# Changelog

## 3.0.0

### Crítico
- Configuración dual de launch screen (`UILaunchScreen` + storyboard) y checks CI para atacar el viewport legacy/letterboxing visto en iPhone 16.
- Layout raíz y navegación inferior rehechos; tab bar se oculta con el teclado.
- Modelo global compartido: ningún personaje puede provocar una recarga de modelo al seleccionarlo.
- Qwen3 1.7B pasa a ser el equilibrio por defecto para reducir presión de memoria.
- Gestión explícita de memory warnings y liberación de sesión MLX.

### Comportamiento
- Un único campo **COMPORTAMIENTO** por personaje.
- Comportamiento = autoridad de máxima prioridad.
- Memoria y conversación se tratan como hechos/contexto, no instrucciones.
- Estado emocional y escenarios dejan de competir con el prompt.
- Salas single-speaker y sanitización de apropiación de diálogo, también inline.

### Rendimiento/UI
- Estética industrial simplificada.
- Avatar sin animación permanente a 30 FPS.
- Caché de imágenes con límite y avatar redimensionado.
- Streaming UI throttled.
- Contexto y max tokens más conservadores.
- TTS por streaming desactivado de fábrica para evitar verbalizar texto no final.

### Compatibilidad
- Mantiene bundle id `dev.castmind.localai`.
- Conserva campos legacy necesarios para cargar datos V2.
