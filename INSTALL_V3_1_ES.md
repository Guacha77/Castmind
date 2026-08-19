# Instalar Castmind V3.1.1

1. Descomprime `Castmind-V3.1.1.zip`.
2. En PowerShell entra en esa carpeta.
3. Ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_1_1_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```

4. Después:

```powershell
cd "C:\Users\chagu\Documents\Castmind"
git status
git add .
git commit -m "Castmind V3.1.1 composer visibility fix"
git push
```

5. Espera a `Build Castmind V3.1.1 unsigned IPA` en GitHub Actions.
6. Descarga `Castmind-V3.1.1-unsigned-ipa`, extrae `Castmind-unsigned.ipa` e instálalo con AltStore.
