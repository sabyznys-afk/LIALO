@echo off
setlocal
chcp 65001 >nul

set "PROJ_DIR=%~dp0"
if "%PROJ_DIR:~-1%"=="\" set "PROJ_DIR=%PROJ_DIR:~0,-1%"

set "GODOT_BIN="

if defined GODOT_EXE (
    if exist "%GODOT_EXE%" set "GODOT_BIN=%GODOT_EXE%"
)

if not defined GODOT_BIN (
    for /f "delims=" %%G in ('where godot 2^>nul') do (
        if not defined GODOT_BIN (
            if exist "%%G" set "GODOT_BIN=%%G"
        )
    )
)

if not defined GODOT_BIN (
    if exist "%LOCALAPPDATA%\Microsoft\WinGet\Packages" (
        for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine*") do (
            for %%F in ("%%D\Godot*_win64.exe") do (
                if not defined GODOT_BIN (
                    if exist "%%F" set "GODOT_BIN=%%F"
                )
            )
        )
    )
)

if not defined GODOT_BIN (
    if exist "C:\Godot\Godot.exe" set "GODOT_BIN=C:\Godot\Godot.exe"
)

if not defined GODOT_BIN (
    if exist "%USERPROFILE%\Godot\Godot.exe" set "GODOT_BIN=%USERPROFILE%\Godot\Godot.exe"
)

if not defined GODOT_BIN (
    echo [CHYBA / ERROR] Godot 4.7+ nebol najdeny / was not found.
    echo Nastavte GODOT_EXE, pridajte godot do PATH, alebo nainstalujte cez:
    echo   winget install GodotEngine.GodotEngine
    pause
    exit /b 1
)

start "" "%GODOT_BIN%" --path "%PROJ_DIR%"
