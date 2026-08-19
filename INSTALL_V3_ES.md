# Instalar / actualizar Castmind V3 desde Windows

## 1. Aplicar V3 al repo actual

Descomprime `Castmind-V3.0.zip`, abre PowerShell dentro de la carpeta y ejecuta:

```powershell
Set-ExecutionPolicy -Scope Process Bypass
.\DEPLOY_V3_TO_EXISTING_REPO.ps1 -RepoPath "C:\Users\chagu\Documents\Castmind"
```

El script crea un backup completo junto al repo y conserva `.git`.

Después:

```powershell
cd "C:\Users\chagu\Documents\Castmind"
git status
git add .
git commit -m "Castmind V3"
git push
```

El workflow se ejecuta automáticamente en `main`. También puede lanzarse manualmente desde Actions.

## 2. Compilar

En GitHub → Actions abre **Build Castmind V3 unsigned IPA**. La ejecución correcta debe corresponder al commit de V3.

La build valida además del bundle normal:

- `UILaunchScreen` con `LaunchBackground`;
- `UILaunchStoryboardName = LaunchScreen`;
- `UIRequiresFullScreen = true`;
- existencia de `LaunchScreen.storyboardc` dentro de `Castmind.app`;
- `Payload/Castmind.app` y su ejecutable.

Si queda verde, descarga el artifact **Castmind-V3-unsigned-ipa**, extrae `Castmind-unsigned.ipa` e instálalo con AltStore.

## 3. Actualizar en el iPhone

Instala V3 encima de la app existente para conservar el sandbox. Si el iPhone siguiera mostrando el viewport de compatibilidad de una build antigua, elimina Castmind y haz una instalación limpia de V3; antes exporta un backup si tienes datos que quieras conservar.

## 4. Primera prueba

1. Comprueba que Castmind ocupa el área completa de la pantalla.
2. Usa Qwen3 1.7B como modelo `BAL / DEFAULT`.
3. Crea dos personajes con prompts de **COMPORTAMIENTO** muy diferentes.
4. Prueba cada uno en un chat individual.
5. Crea una sala con ambos y confirma que cada burbuja contiene solo el diálogo de su autor.
6. Activa el HUD técnico si quieres medir TTFT/tokens por segundo.

## 5. Si GitHub falla

Abre el primer paso rojo y copia desde la primera línea que contenga `error:`. No modifiques paquetes a ciegas: la build de GitHub es el gate real de Xcode/iOS que no se puede ejecutar desde Windows.
