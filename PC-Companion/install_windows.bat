@echo off
setlocal
cd /d "%~dp0"
where py >nul 2>nul || (echo Python 3 no esta instalado o no esta en PATH.& pause & exit /b 1)
py -3 -m venv .venv
call .venv\Scripts\activate.bat
python -m pip install --upgrade pip
pip install -r requirements.txt
if not exist config.json copy /Y config.example.json config.json >nul
echo.
echo Castmind Stream Bridge V3 instalado.
echo Edita config.json si quieres OBS/TTS personalizado y ejecuta run_bridge.bat.
pause
