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
            for %%F in ("%%D\Godot*_win64_console.exe") do (
                if not defined GODOT_BIN (
                    if exist "%%F" set "GODOT_BIN=%%F"
                )
            )
            if not defined GODOT_BIN (
                for %%F in ("%%D\Godot*_win64.exe") do (
                    if not defined GODOT_BIN (
                        if exist "%%F" set "GODOT_BIN=%%F"
                    )
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

echo Exportuji hru LIALO pro Windows (build\windows\LIALO.exe)...
if not exist "%PROJ_DIR%\build\windows" mkdir "%PROJ_DIR%\build\windows"
"%GODOT_BIN%" --headless --export-release "Windows Desktop" "%PROJ_DIR%\build\windows\LIALO.exe" --path "%PROJ_DIR%"
echo.
if %ERRORLEVEL% neq 0 (
    echo [CHYBA / ERROR] Export zlyhal / failed. Exit code: %ERRORLEVEL%
    pause
    exit /b %ERRORLEVEL%
)
echo Hotovo! Vyexportovanou hru najdes v: %PROJ_DIR%\build\windows\LIALO.exe
explorer "%PROJ_DIR%\build\windows"
pause
