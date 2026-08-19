# Castmind V2 — Informe de validación

Fecha de cierre de esta revisión: 2026-08-19.

## Resultado
El proyecto V2 está preparado para la compilación real de iOS mediante el workflow macOS incluido. En el entorno de creación se han validado fuente, datos, lógica portable, protocolo de red, assets y empaquetado CI. La única comprobación que no puede ejecutarse fuera de macOS es `xcodebuild` contra el SDK real de iOS; el workflow de GitHub Actions es la prueba final de type-check/link/build en dispositivo.

## Validaciones ejecutadas

### Swift
- 23 archivos Swift analizados juntos con `swiftc -swift-version 5 -parse`: **OK**.
- Repetido después de los últimos fixes de migración, insights y concurrencia de conversaciones: **OK**.
- Test ejecutable de lógica portable (`Domain + MemoryEngine + StateAnalyzer`): **OK**.
  - captura de memoria;
  - ranking de recuerdos relevantes;
  - modificación/clamp de estado emocional;
  - round-trip Codable de `CastmindLibrary`.

### MLX API
Se revisó la API usada por `AIEngine.swift` contra el tag exacto `mlx-swift-lm 3.31.4`:
- `ChatSession(ModelContainer, instructions:, generateParameters:, additionalContext:)` existe;
- `streamResponse(to:)` devuelve streaming de `String`;
- `respond(to:)` existe;
- `LLMRegistry.qwen3_0_6b_4bit`, `qwen3_5_2b_4bit` y `qwen3_4b_4bit` existen;
- el macro Hugging Face admite progress handler.

### Persistencia y migración
- V2 usa escrituras JSON atómicas y avatares JPEG independientes.
- La migración se ajustó a la estructura real de V1: `castmind-profile.json`, `castmind-messages.json`, `castmind-generation.json` en Documents y `JSONEncoder/Decoder` con estrategia de fecha por defecto.
- Se conserva el bundle identifier V1 `dev.castmind.localai` para permitir una actualización sobre la instalación existente.

### Stream Bridge
- `castmind_bridge.py`: `python -m py_compile`: **OK**.
- Test WebSocket real en localhost con un cliente que simula el iPhone: **OK**.
- Evento probado: `assistant_reply`, personaje `Gregorio`, cue `happy`, texto `Prueba V2`.
- ACK del servidor y actualización de estado: **OK**.
- En este entorno se aislaron OBS/TTS/mDNS con dobles de prueba; su integración completa depende de Windows + OBS y se valida en el equipo final.

### Configuración / recursos
- `project.yml`: YAML válido.
- `.github/workflows/build-unsigned-ipa.yml`: YAML válido.
- `Info.plist`: plist válido y claves de bundle/permisos presentes.
- `PrivacyInfo.xcprivacy`: plist válido; tracking desactivado.
- Todos los `Contents.json` de Asset Catalog: JSON válido.
- AppIcon: PNG 1024×1024.
- Sin API keys ni secretos de servicios de IA en el código.
- Sin archivos `TODO`/`FIXME` de producción pendientes.

### Workflow IPA
El workflow conserva los fixes que fueron necesarios en la build real de V1:
- `-skipPackagePluginValidation`;
- `-skipMacroValidation`;
- code signing desactivado para generar un IPA unsigned;
- validación de `Info.plist`, `CFBundlePackageType == APPL` y ejecutable;
- raíz del IPA limitada a `Payload/`;
- un único `Payload/Castmind.app`;
- `unzip -t` y revalidación tras extraer;
- SHA-256 separado;
- artifact `Castmind-V2-unsigned-ipa`.

## Edge cases corregidos durante la auditoría
- Regenerar ya no duplica el último mensaje de usuario.
- Una respuesta en curso permanece ligada a su conversación aunque el usuario cambie de chat.
- Cancelar limpia correctamente el mensaje streaming incompleto.
- Un cambio de personaje no puede cambiar de modelo a mitad de una generación activa.
- Una explicación generada por swipe se escribe en la conversación original aunque el usuario cambie de chat.
- TTS mantiene la sesión de audio mientras existan frases en cola.
- Speech evita quitar un input tap inexistente.
- El deploy V2 elimina fuentes V1 antes de copiar para evitar que XcodeGen compile archivos obsoletos.
- El backup previo al deploy se crea fuera del repo para que `git add .` no lo suba por accidente.

## Limitaciones que requieren hardware/servicios finales
- No se puede ejecutar Xcode/iOS SDK en este entorno Linux. La build verde del workflow es obligatoria antes de instalar V2.
- Rendimiento real, temperatura, TTFT y tokens/s deben medirse en el iPhone 16; V2 incluye benchmark/HUD precisamente para ello.
- La disponibilidad de voces y reconocimiento on-device depende de las voces/idiomas instalados en iOS.
- OBS y el TTS de Windows deben probarse en el PC del stream tras instalar las dependencias del companion.

## Criterio de release
No considerar V2 instalada hasta que:
1. GitHub Actions termine verde;
2. AltStore instale el IPA nuevo;
3. el modelo Equilibrado cargue en el iPhone 16;
4. una respuesta aparezca en streaming y se lea en voz alta;
5. cerrar/reabrir confirme auto-carga;
6. crear un segundo personaje confirme aislamiento de conversación/memoria.
