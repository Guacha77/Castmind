param(
    [Parameter(Mandatory=$true)]
    [string]$RepoPath
)

$ErrorActionPreference = "Stop"
$Source = Split-Path -Parent $MyInvocation.MyCommand.Path
$RepoPath = (Resolve-Path $RepoPath).Path
$Stamp = Get-Date -Format "yyyyMMdd-HHmmss"
$Backup = "${RepoPath}_backup_before_v3_2_$Stamp"

Write-Host "Creating backup: $Backup"
Copy-Item -Path $RepoPath -Destination $Backup -Recurse -Force

Get-ChildItem -Path $RepoPath -Force | Where-Object { $_.Name -ne ".git" } | Remove-Item -Recurse -Force

Get-ChildItem -Path $Source -Force | Where-Object {
    $_.Name -notin @("DEPLOY_V3_2_TO_EXISTING_REPO.ps1")
} | ForEach-Object {
    Copy-Item -Path $_.FullName -Destination $RepoPath -Recurse -Force
}
Copy-Item -Path (Join-Path $Source "DEPLOY_V3_2_TO_EXISTING_REPO.ps1") -Destination $RepoPath -Force

Write-Host ""
Write-Host "Castmind V3.2.0 Stability copied to: $RepoPath" -ForegroundColor Green
Write-Host "Backup: $Backup" -ForegroundColor Yellow
Write-Host ""
Write-Host "Next:"
Write-Host "  cd `"$RepoPath`""
Write-Host "  git status"
Write-Host "  git add ."
Write-Host "  git commit -m `"Castmind V3.2 stability and role fidelity`""
Write-Host "  git push"
