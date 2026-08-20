# Instalación Castmind V3.3.0

1. Descomprime `Castmind-V3.3-ConversationEngine.zip`.
2. Abre PowerShell en la carpeta extraída.
3. Ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_3_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```

4. Sube la versión:

```powershell
cd "C:\Users\chagu\Documents\Castmind"
git status
git add .
git commit -m "Castmind V3.3 conversation engine"
git push
```

5. Espera a que GitHub Actions quede verde.
6. Descarga `Castmind-V3.3.0-unsigned-ipa`.
7. Descomprime el artifact e instala `Castmind-unsigned.ipa` con AltStore.

La primera vez que uses BALANCED se descargará Qwen3.5 2B, porque V3.3 cambia el modelo recomendado respecto a V3.2.
