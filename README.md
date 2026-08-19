# Castmind V2

Castmind V2 convierte un iPhone en un **motor local de personajes IA para conversación y stream**. No usa OpenAI, ElevenLabs, analytics ni una cuenta propia: el LLM se descarga bajo demanda y se ejecuta con MLX en el dispositivo.

## Qué cambia en V2

### Arranque y rendimiento
- Auto-carga del último modelo al abrir o volver a la app.
- Warm-up opcional para reducir la espera de la primera respuesta.
- Tres perfiles: **Rápido** (Qwen3 0.6B), **Equilibrado** (Qwen3.5 2B) y **Calidad** (Qwen3 4B).
- Modelo compartido por todos los personajes; cambiar de personaje no duplica el modelo en RAM.
- Benchmark local, HUD técnico opcional y adaptación a `ProcessInfo.thermalState`.
- Liberación manual de RAM y gestión de modelos descargados.

### Chat
- Respuesta visible en streaming desde el primer texto útil.
- Los bloques `<think>...</think>` se filtran de la respuesta visible.
- Swipe izquierdo en una respuesta: genera **“Por qué respondió así”**, un resumen breve de factores observables (personalidad, memoria, estado y mensaje), no razonamiento interno oculto.
- Teclado descartable con swipe, toque fuera y botón `Cerrar`.
- Copiar, reproducir voz, regenerar y borrar mensajes.
- Conversaciones separadas, búsqueda y pin.

### Personajes
- Crear tantos personajes como quieras con presets o desde cero.
- Nombre, rol, personalidad, estilo, límites, saludo, color y wake word propios.
- Temperatura, top-p, tokens máximos, contexto y modelo preferido por personaje.
- Imagen desde Fotos; avatar con respiración, bob, tilt, glow y pulso reactivo mientras habla/escucha.
- Voz iOS, velocidad, tono, volumen y TTS automático independientes.
- Relaciones estructuradas con personas/viewers.
- Duplicar, exportar e importar personajes.

### Voz
- Speech.framework con `requiresOnDeviceRecognition = true`.
- Push-to-talk o modo manos libres con detección de silencio.
- Interrumpir una respuesta simplemente volviendo a activar el micro.
- TTS con `AVSpeechSynthesizer`, sesión de audio dedicada y modo **hablar mientras genera** por frases.
- Wake words: por ejemplo `Gregorio, ...` puede enrutar automáticamente la entrada al personaje correcto.

### Memoria y personalidad dinámica
- Memoria totalmente independiente y desactivable por personaje.
- Captura automática opcional de datos, preferencias, eventos, promesas y relaciones.
- Importancia, pin, búsqueda y borrado.
- Recuperación por relevancia en vez de inyectar todos los recuerdos en cada prompt.
- Decay/olvido inteligente para recuerdos viejos de poca importancia.
- Estado persistente: ira, confianza, energía, humor, estrés, entusiasmo y afecto.

### Salas y Stream Mode
- Salas de hasta cuatro personajes; responden en turnos usando lo dicho por los demás.
- Modo Stream a pantalla completa con avatar, subtítulo actual y controles mínimos.
- Escenarios: Normal, Just Chatting, Gaming, IRL y escenarios personalizados.

### Stream Bridge V2
`PC-Companion/` contiene un companion Windows con:
- WebSocket local autenticado con clave compartida.
- anuncio mDNS/Bonjour `_castmind._tcp` para descubrimiento automático desde el iPhone;
- dashboard Tkinter;
- subtítulos en OBS;
- alternancia `Castmind - Idle` / `Castmind - Talking`;
- TTS local con `pyttsx3`;
- fallback a IP/puerto manual.

## Privacidad
- La inferencia del personaje es local.
- La transcripción exige reconocimiento on-device.
- Personajes, conversaciones y memorias se guardan en Application Support.
- No hay analytics, cuentas, API keys ni tracking.
- Internet solo es necesario para descargar por primera vez los modelos y, si procede, para compilar/instalar la app.

## Actualizar desde V1
V2 mantiene el bundle id `dev.castmind.localai`. En el primer arranque busca los archivos reales de V1 en Documents (`castmind-profile.json`, `castmind-messages.json` y `castmind-generation.json`) y, si aún no existe una biblioteca V2, migra el personaje, conversación, memoria textual, voz, parámetros de generación, onboarding y configuración básica de Stream Bridge.

Para aplicar el código V2 a tu repo actual desde Windows, lee **`INSTALL_V2_ES.md`** o usa `DEPLOY_V2_TO_EXISTING_REPO.ps1`.

## Build
El repositorio usa XcodeGen. El workflow `.github/workflows/build-unsigned-ipa.yml`:
1. genera `Castmind.xcodeproj`;
2. resuelve paquetes;
3. compila Release para `generic/platform=iOS` sin firma;
4. valida `Info.plist` y ejecutable;
5. crea un IPA estándar `Payload/Castmind.app`;
6. reabre y valida el IPA;
7. publica `Castmind-V2-unsigned-ipa` como artifact.

Dependencias fijadas:
- `mlx-swift-lm` 3.31.4
- `swift-huggingface` 0.9.0
- `swift-transformers` 1.3.0

## Estructura
```text
Castmind-V2.0/
├─ Castmind/
│  ├─ App/
│  ├─ Components/
│  ├─ Core/
│  ├─ Models/
│  ├─ Resources/
│  └─ Views/
├─ PC-Companion/
├─ .github/workflows/build-unsigned-ipa.yml
├─ project.yml
├─ INSTALL_V2_ES.md
├─ CHANGELOG.md
├─ ARCHITECTURE.md
├─ THIRD_PARTY_NOTICES.md
└─ VALIDATION_REPORT.md
```
