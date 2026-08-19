# Instalar / actualizar Castmind V2 desde Windows

## A. Sustituir V1 por V2 en tu repo actual
1. Descomprime `Castmind-V2.0.zip`.
2. Abre PowerShell en la carpeta descomprimida.
3. Ejecuta:
```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V2_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```
El script crea primero `Castmind_backup_before_v2_FECHA` junto a la carpeta del repo (fuera de Git, para no subir el backup por accidente) y después sustituye limpiamente el código V1 por V2.

4. En CMD/PowerShell:
```powershell
cd C:\Users\chagu\Documents\Castmind
git status
git add .
git commit -m "Castmind V2"
git push
```

## B. Compilar el IPA
1. GitHub → `Guacha77/Castmind` → **Actions**.
2. Abre **Build Castmind V2 unsigned IPA**.
3. `Run workflow`.
4. Si termina verde, descarga el artifact **Castmind-V2-unsigned-ipa**.
5. Extrae el ZIP y usa **Castmind-unsigned.ipa**.

El workflow compila en `macos-26`, usa validación omitida para plugins/macros de paquetes en CI y valida la estructura del IPA antes de publicarlo.

## C. Instalar con AltStore
1. Deja AltServer activo.
2. Pasa `Castmind-unsigned.ipa` al iPhone.
3. AltStore → My Apps → `+` → selecciona el IPA.
4. Al compartir bundle identifier con V1, debería instalarse como actualización; los datos V1 permanecen en el sandbox y V2 intenta migrarlos en el primer arranque.

## D. Primer arranque V2
- La app intentará cargar automáticamente el modelo configurado.
- El perfil Equilibrado usa Qwen3.5 2B 4-bit. La primera vez tendrá que descargarlo aunque ya tuvieras Qwen3 1.7B de V1.
- Si prefieres empezar sin esa descarga, ve al perfil Rápido Qwen3 0.6B.
- Abre Personajes → Gregorio → Voz y pulsa **Probar voz**.
- En Chat, escribe un mensaje: debería aparecer progresivamente y empezar a hablar por frases si `Hablar mientras genera` está activo.

## E. Stream Bridge V2
1. En `PC-Companion`, ejecuta `install_windows.bat` una vez.
2. Edita `config.json`; cambia `secret`.
3. Ejecuta `run_bridge.bat`.
4. Castmind → Ajustes → Stream Bridge → activar → descubrir PC automáticamente.
5. Usa la misma clave compartida en iPhone y PC.

## Si GitHub Actions falla
Abre el paso rojo **Build Release app for iPhone** y copia desde la primera línea `error:`. No modifiques MLX al azar: el workflow ya incluye `-skipPackagePluginValidation` y `-skipMacroValidation`, que fueron necesarios en V1.
