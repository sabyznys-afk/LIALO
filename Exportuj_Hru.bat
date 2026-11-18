@echo off
chcp 65001 >nul
echo Exportuji hru LIALO pro Windows (build\windows\LIALO.exe)...
if not exist "D:\downpour-godot\build\windows" mkdir "D:\downpour-godot\build\windows"
"C:\Users\arnos\Godot\Godot.exe" --headless --export-release "Windows Desktop" "D:\downpour-godot\build\windows\LIALO.exe" --path "D:\downpour-godot"
echo.
echo Hotovo! Vyexportovanou hru najdes v: D:\downpour-godot\build\windows\LIALO.exe
explorer "D:\downpour-godot\build\windows"
pause
