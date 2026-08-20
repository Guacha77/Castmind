# Castmind V3.3.0 — Conversation Engine

V3.3 conserva la estabilidad y el layout de V3.2 y rehace el motor conversacional alrededor de cómo esperan trabajar los modelos chat locales:

- historial real `user` / `assistant` en vez de pegar la conversación dentro del system prompt;
- perspectiva independiente por personaje en salas;
- persona estable entre turnos, incluso cuando el prompt original es enorme;
- Qwen3.5 2B como modelo recomendado y Qwen3 4B como opción de máxima calidad;
- sampling alineado con las recomendaciones de Qwen para modo no-thinking;
- detector de loops, respuestas duplicadas y fugas meta antes de mostrar la respuesta;
- reintento oculto con sampling sano cuando una generación colapsa;
- se mantienen los límites de memoria, limpieza MLX, teclado/composer fijo, voz y borrado de salas de V3.2.

## Deploy

```powershell
cd "C:\Users\chagu\Downloads\Castmind-V3.3-ConversationEngine"
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_3_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"

cd "C:\Users\chagu\Documents\Castmind"
git status
git add .
git commit -m "Castmind V3.3 conversation engine"
git push
```

GitHub Actions genera el artifact `Castmind-V3.3.0-unsigned-ipa`. Descomprímelo e instala `Castmind-unsigned.ipa` con AltStore.
