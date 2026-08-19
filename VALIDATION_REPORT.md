# Castmind V3 — Informe de validación

Fecha de preparación: 2026-08-19.

## Resultado

V3 ha pasado todas las validaciones que pueden ejecutarse fuera de macOS/Xcode. El workflow incluido es deliberadamente el último gate: compila con el SDK real de iOS y además inspecciona el `Castmind.app` construido antes de crear el IPA.

## Validado en este entorno

### Swift / datos
- Todos los archivos `.swift` pasan `swiftc -frontend -parse -swift-version 5`.
- Compatibilidad Codable V2→V3 probada eliminando `behaviorPrompt` de un personaje serializado y volviéndolo a decodificar.
- Biblioteca completa encode/decode probada.
- `GenerationSettings.default.maxTokens == 128`.
- TTS por streaming desactivado por defecto.
- `MemoryEngine` probado: captura y recuperación relevante.
- `ReplySanitizer` probado con:
  - otro personaje en la línea siguiente;
  - otro personaje inyectado en la **misma línea**;
  - diálogo del usuario inyectado dentro de una respuesta directa.

### Arquitectura
Comprobaciones estáticas:
- modelo activo = `settings.modelChoice` global;
- no quedan rutas activas que seleccionen `character.preferredModel` para inferencia;
- prompt contiene `COMPORTAMIENTO — AUTORIDAD MÁXIMA`;
- salas llaman a `ReplySanitizer.room`;
- memoria solo se recupera si `character.memory.enabled`;
- editor no ofrece “modelo propio”;
- perfil BAL = Qwen3 1.7B y QLT = Qwen3.5 2B;
- `AIEngine` libera `activeSession` tras cada inferencia;
- `AvatarView` ya no usa `TimelineView` permanente.

### iOS resources / full-screen
- `Info.plist` válido.
- `UILaunchScreen -> UIColorName = LaunchBackground`.
- `UILaunchStoryboardName = LaunchScreen`.
- `UIRequiresFullScreen = true`.
- Portrait-only.
- `LaunchScreen.storyboard` XML válido.
- Privacy manifest válido.
- todos los `Contents.json` de assets válidos.
- AppIcon 1024×1024.
- `project.yml` válido; iOS 18, iPhone-only, bundle `dev.castmind.localai`, versión 3.0.0 / build 300.

### CI / IPA
El workflow valida en la app **ya compilada**:
- claves básicas de bundle;
- ejecutable;
- launch storyboard name;
- full-screen flag;
- `UILaunchScreen:UIColorName`;
- existencia de `LaunchScreen.storyboardc`;
- estructura estándar `Payload/Castmind.app`;
- reapertura y `unzip -t` del IPA.

### Companion
- `castmind_bridge.py` pasa `py_compile`.
- protocolo y formato no se han roto respecto a V2; versión anunciada actualizada a 3.

### Higiene
- scan de API keys OpenAI/ElevenLabs y marcadores de secretos: limpio.
- scan de TODO/FIXME de producción: limpio.
- documentación de instalación actualizada a V3.

## Lo que NO puede certificarse aquí

Este entorno no dispone de Xcode ni del SDK de iOS. Por ello no es posible afirmar que V3 está validada físicamente en un iPhone 16 antes de ejecutar GitHub Actions y probar el IPA en el dispositivo.

En particular, estos dos puntos necesitan el gate real:

1. **Full-screen físico:** el código y el bundle están preparados y CI comprobará que la configuración acaba realmente en `Castmind.app`; el resultado visual final se confirma instalando V3 en el iPhone.
2. **Cierres por memoria/rendimiento:** se han reducido las causas conocidas (modelo default menor, modelo global, caché de avatar, menos contexto/tokens, no animación permanente, liberación de sesión, memory-warning handler), pero la presión térmica/RAM real solo puede medirse en el iPhone.

## Gate de release

No considerar V3 lista para instalar hasta que **Build Castmind V3 unsigned IPA** quede verde en GitHub Actions. Si queda roja, el primer error de `xcodebuild` debe corregirse antes del sideload.
