# Castmind V3.1 — Validation Report

Validaciones ejecutadas en el entorno de construcción de ChatGPT:

- `swiftc -frontend -parse` sobre todos los archivos Swift: OK.
- Test ejecutable de `PromptBudgeter`: OK.
  - prompt fuente ~89k caracteres -> contexto efectivo <= 12k para modelo Balanced.
  - conserva reglas de alta prioridad.
  - limita inputs de usuario.
- Test ejecutable V3.1 de dominio/memoria/sanitizador: OK.
  - `CREATE_BLANK` realmente vacío.
  - memoria automática funcional.
  - sanitizador de salas impide diálogo de otro participante en la misma respuesta.
- `Info.plist`: XML válido, `UILaunchScreen` moderno, `UIRequiresFullScreen=true`, sin `UILaunchStoryboardName`.
- `project.yml`: parse YAML válido; `INFOPLIST_FILE` explícito y `GENERATE_INFOPLIST_FILE=NO`.
- Workflow GitHub Actions: YAML válido y validaciones estrictas de versión/plist/IPA.
- Companion Python: parse sintáctico.
- Búsqueda de secretos/API keys hardcoded: sin credenciales de producción.
- Invariantes estáticos: composer de Chat/Room usa `safeAreaInset`; Room tiene micrófono; PromptBudgeter se usa en chat, salas e insight.

## Limitación de validación

Este entorno no incluye Xcode ni el SDK iOS. La compilación/link final para `generic/platform=iOS`, el comportamiento del teclado real, Speech.framework real, presión térmica y estabilidad física se verifican finalmente en el runner macOS de GitHub Actions y en el iPhone.
