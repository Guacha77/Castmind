# Instalar Castmind V3.1 sobre tu repositorio actual

1. Descomprime este ZIP, por ejemplo en:

```text
C:\Users\chagu\Downloads\Castmind-V3.1
```

2. Abre PowerShell dentro de esa carpeta y ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_1_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```

3. Después:

```powershell
cd "C:\Users\chagu\Documents\Castmind"
git status
git add .
git commit -m "Castmind V3.1 stability and voice update"
git push
```

4. GitHub Actions ejecutará `Build Castmind V3.1 unsigned IPA`.

5. Si queda verde, descarga el artifact `Castmind-V3.1-unsigned-ipa`, extrae `Castmind-unsigned.ipa` e instálalo con AltStore.

No borres la app antes de actualizar si quieres conservar los datos existentes.
