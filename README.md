# Castmind V3.2.0 Stability

Castmind es una app iOS local para conversar con personajes mediante modelos MLX sin API externa.

Esta versión parte de V3.1.1 + Composer Layout Fix y se centra en tres objetivos:
1. que la app sobreviva conversaciones largas sin acumular memoria MLX;
2. que personajes con prompts muy grandes mantengan identidad y coherencia;
3. que las salas sean utilizables y borrables.

## Modelo recomendado
Qwen3 1.7B sigue siendo la opción recomendada para sesiones largas. Qwen3.5 2B funciona con protecciones de memoria más agresivas, pero usa más RAM por sus pesos.

## Instalación sobre el repo existente

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_2_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```

Después:

```powershell
cd "C:\Users\chagu\Documents\Castmind"
git status
git add .
git commit -m "Castmind V3.2 stability and role fidelity"
git push
```

GitHub Actions generará el artifact `Castmind-V3.2.0-unsigned-ipa`.
