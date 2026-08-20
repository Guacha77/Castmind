# Instalación Castmind V3.2.0

1. Descomprime el ZIP fuente.
2. Abre PowerShell dentro de la carpeta descomprimida.
3. Ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_2_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```

4. Sube los cambios:

```powershell
cd "C:\Users\chagu\Documents\Castmind"
git status
git add .
git commit -m "Castmind V3.2 stability and role fidelity"
git push
```

5. En GitHub > Actions espera la build verde.
6. Descarga `Castmind-V3.2.0-unsigned-ipa`.
7. Descomprime el artifact y abre `Castmind-unsigned.ipa` con AltStore.
