# Castmind V3

Castmind V3 es un runtime local de personajes IA para iPhone orientado a conversación y stream. La prioridad de esta versión es **pantalla nativa, estabilidad, baja latencia y obediencia al prompt**.

## Cambios principales

### Pantalla completa
- `UILaunchScreen` moderno con `LaunchBackground`.
- `LaunchScreen.storyboard` incluido y validado en CI.
- `UILaunchStoryboardName = LaunchScreen` y `UIRequiresFullScreen = true` para el target iPhone.
- El workflow falla si el bundle construido pierde cualquiera de esas piezas.
- UI raíz a tamaño infinito y fondos edge-to-edge; el contenido respeta safe areas.
- Barra inferior propia de 54 pt y oculta mientras aparece el teclado para no comprimir Chat.

### Diseño V3
- Lenguaje visual industrial: negro, gris/concreto, líneas de 1 px, tipografía monoespaciada y naranja como señal.
- Sin glassmorphism pesado, blur continuo ni gradientes decorativos.
- Personajes en índice compacto; chat, salas, editor, onboarding, stream mode y ajustes rediseñados.
- Avatar estático en reposo; solo reacciona al hablar/escuchar, evitando un render loop permanente.

### Un único prompt: COMPORTAMIENTO
Cada personaje conserva un solo campo visible **COMPORTAMIENTO**. Es la autoridad de máxima prioridad del prompt. Ahí se escribe identidad, forma de hablar, reglas, objetivos, relación con el usuario, límites y cualquier otra instrucción.

Los campos legacy de V2 permanecen solo para poder decodificar/migrar personajes antiguos, pero no compiten con `behaviorPrompt`.

### Obediencia y salas
- Memoria = hechos, nunca instrucciones.
- Estado emocional ya no se inyecta como una segunda personalidad.
- Escenarios ya no se inyectan en el prompt del personaje.
- Salas con generación **single-speaker**: cada turno solo pertenece al personaje asignado.
- `ReplySanitizer` corta prefijos de otro participante incluso si el modelo intenta incluirlos en la misma línea.
- En salas la creatividad/contexto/salida se limitan de forma más conservadora para evitar role drift.

### Rendimiento y estabilidad
- Modelo global único: cambiar de personaje ya no cambia/re-carga el modelo.
- Perfil por defecto: **Qwen3 1.7B 4-bit**.
- Rápido: Qwen3 0.6B 4-bit.
- Calidad: Qwen3.5 2B 4-bit.
- Auto-load + warm-up.
- Actualizaciones de streaming agrupadas para no invalidar SwiftUI por cada token.
- Sesión de generación liberada al terminar.
- Avatares redimensionados a máx. 1024 px y cacheados con límite de memoria.
- Respuesta/reciente reducidos automáticamente según perfil térmico.
- Ante `UIApplication.didReceiveMemoryWarningNotification`, Castmind cancela generación/voz y libera el modelo antes de forzar al sistema.

### Memoria
- Memoria independiente por personaje.
- Si la memoria de un personaje está desactivada, sus recuerdos no se capturan **ni se inyectan** en el prompt.
- Captura automática opcional, relevancia, pin e importancia.

### Voz
- Speech.framework con reconocimiento on-device.
- TTS nativo de iOS.
- `speakWhileGenerating` queda desactivado por defecto para priorizar respuesta final correcta; el texto sí aparece en streaming.
- El usuario puede reactivarlo individualmente.

## Modelos

| Perfil | Modelo | Uso recomendado |
|---|---|---|
| FST | Qwen3 0.6B 4-bit | latencia mínima |
| BAL | Qwen3 1.7B 4-bit | **default para iPhone 16** |
| QLT | Qwen3.5 2B 4-bit | mayor capacidad, más RAM |

El modelo se descarga una vez y luego se carga localmente. Todos los personajes comparten el mismo modelo en RAM.

## Build

El proyecto usa XcodeGen y GitHub Actions. `.github/workflows/build-unsigned-ipa.yml`:

1. genera el `.xcodeproj`;
2. resuelve paquetes;
3. compila Release para `generic/platform=iOS` sin firma;
4. valida `Info.plist`, ejecutable y launch configuration;
5. crea `Payload/Castmind.app`;
6. valida el IPA reabriéndolo;
7. publica **Castmind-V3-unsigned-ipa**.

Dependencias fijadas:
- `mlx-swift-lm` 3.31.4
- `swift-huggingface` 0.9.0
- `swift-transformers` 1.3.0

## Actualizar desde tu repo actual

Lee `INSTALL_V3_ES.md` o ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```

Se crea un backup antes de reemplazar el contenido, conservando `.git`.

## Privacidad

No hay OpenAI/ElevenLabs/analytics/cuenta propia. La inferencia y la memoria son locales. Internet se usa para la descarga inicial del modelo y para la compilación remota si usas GitHub Actions.
