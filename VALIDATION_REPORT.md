# Castmind V3.2.0 — Validation report

## Base
Partido de Castmind V3.1.1 + Composer Layout Fix, la rama funcional que ya mostraba correctamente la caja inferior de Chat y Room.

## Cambios críticos validados
- `MLX.Memory.cacheLimit = 32 MB` y limpieza explícita de cache/buffers entre turnos.
- `ChatSession.clear()` antes de liberar cada sesión para soltar KV cache realmente, no solo la referencia Swift.
- KV cache 4-bit (`kvBits: 4`) y prefill de 256 tokens, APIs presentes en `mlx-swift-lm 3.31.4`.
- Dependencia directa `MLX 0.31.4`, compatible con la dependencia usada por `mlx-swift-lm 3.31.4`.
- Presupuesto seguro por modelo + compactación token-aware de último recurso.
- Compilación de prompts muy grandes con núcleo estable 80% + detalles relevantes 20%.
- Guard de respuestas meta/repetitivas y un único intento de reparación a baja temperatura.
- Respuestas defectuosas excluidas del contexto futuro.
- Reinicio limpio del contenedor del modelo tras un error de generación.
- Voz: 300 ms de drenaje entre Speech.framework y el prefill de MLX.
- Salas: mismas protecciones por participante y botón visible para borrarlas.
- Composer inferior de Chat y Room conservado desde Composer Layout Fix.

## Pruebas ejecutadas en este entorno
- Todos los `.swift`: `swiftc -frontend -parse -swift-version 5` -> OK.
- `Info.plist` y `PrivacyInfo.xcprivacy` -> parse OK.
- `project.yml` y workflow GitHub Actions -> YAML parse OK.
- Companion Python -> `py_compile` OK.
- `git diff --no-index --check` -> sin errores de whitespace.
- Stress test de PromptBudgeter con prompt sintético de 375.000 caracteres -> reducido a ~6,3k caracteres manteniendo la cabecera de identidad -> OK.
- RoleplayGuard detecta ejemplos reales tipo “sigo un papel” / “no me saldré del papel” y no marca respuestas normales -> OK.

## Validación que requiere GitHub Actions / iPhone
Este contenedor no tiene SDK iOS/Xcode, por lo que el typecheck/link final con SwiftUI + MLX debe hacerlo el workflow. El workflow conserva las validaciones de bundle/IPA y está actualizado a 3.2.0 (build 320).

En dispositivo conviene probar 20+ turnos seguidos con Qwen3 1.7B y después con Qwen3.5 2B, incluyendo un personaje con prompt muy grande y una sala de 2–4 participantes.
