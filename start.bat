@echo off
rem NullPointer Inc. — sobe o backend e abre o escritorio com um clique
cd /d "%~dp0"

echo [1/2] Subindo o backend...
start "NullPointer Backend" cmd /k backend\.venv\Scripts\python.exe backend\server.py

timeout /t 2 /nobreak >nul

echo [2/2] Abrindo o escritorio...
start "" "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --path office3d

echo Pronto! Feche esta janela.
