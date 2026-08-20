# Castmind V3.2.0 — Stability & Role Fidelity

## Estabilidad de IA local
- Límite explícito de caché reutilizable de MLX para impedir que la memoria crezca entre turnos.
- Limpieza de buffers transitorios después de cada generación, cancelación, warm-up y descarga.
- KV cache cuantizada a 4-bit para reducir de forma fuerte el coste de contexto durante generación.
- Prefill en bloques más pequeños para bajar el pico de memoria de prompts largos.
- Presupuesto de contexto más conservador según tamaño del modelo.
- Compactación token-aware de último recurso antes de crear el KV cache: un prompt enorme se reduce para ese turno en vez de intentar una asignación peligrosa.
- Mayor separación temporal entre Speech.framework y MLX tras terminar una grabación.
- Perfil automático prioriza estabilidad térmica en lugar de usar siempre el perfil máximo.

## Fidelidad de personaje
- Nuevo compilador de comportamiento estable: el 80% del prompt efectivo es un núcleo fijo que no cambia con cada mensaje.
- El prompt original del personaje se conserva completo; solo se compacta la vista usada por inferencia.
- Nuevo wrapper de identidad menos propenso a provocar comentarios meta sobre “papeles”, “roles” o instrucciones.
- Respuestas meta o con loops se detectan y se reparan una sola vez a baja temperatura.
- Respuestas rotas no vuelven a entrar en el contexto de los siguientes turnos.
- Menor temperatura/top-p efectiva cuando el prompt es grande para mejorar coherencia y obediencia.
- Penalización ligera de repetición para evitar bucles de modelos pequeños.

## Salas
- El mismo sistema de identidad, memoria y estabilidad se aplica a cada participante.
- Los mensajes meta defectuosos no contaminan a los siguientes personajes.
- Reparación de turnos anómalos antes de guardarlos.
- Botón de papelera visible en el índice de salas con confirmación de borrado.
- Se mantiene voz para hablar con toda la sala.

## UI
- Conserva el Composer Layout Fix que mantiene las cajas de texto visibles en Chat y Room.
