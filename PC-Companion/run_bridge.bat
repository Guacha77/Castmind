@echo off
cd /d "%~dp0"
if not exist .venv\Scripts\python.exe (
  echo Primero ejecuta install_windows.bat
  pause
  exit /b 1
)
.venv\Scripts\python.exe castmind_bridge.py
