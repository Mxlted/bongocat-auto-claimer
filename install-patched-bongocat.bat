@echo off
setlocal EnableExtensions

title BongoCat Auto Claimer Installer
color 0B >nul 2>&1

set "SOURCE_DLL=%~dp0Assembly-CSharp.dll"
set "DEFAULT_TARGET_DIR=C:\Program Files (x86)\Steam\steamapps\common\BongoCat\BongoCat_Data\Managed"
set "TARGET_DIR=%~1"
set "NO_PAUSE="

if /I "%~1"=="/?" goto :usage
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage
if /I "%~1"=="--no-pause" (
    set "TARGET_DIR="
    set "NO_PAUSE=1"
)
if /I "%~2"=="--no-pause" set "NO_PAUSE=1"

if "%TARGET_DIR%"=="" set "TARGET_DIR=%BONGOCAT_MANAGED_DIR%"
if "%TARGET_DIR%"=="" set "TARGET_DIR=%DEFAULT_TARGET_DIR%"

if /I "%~nx1"=="Assembly-CSharp.dll" (
    set "TARGET_DLL=%~1"
    for %%I in ("%~1") do set "TARGET_DIR=%%~dpI"
) else (
    set "TARGET_DLL=%TARGET_DIR%\Assembly-CSharp.dll"
)
set "BACKUP_DLL=%TARGET_DLL%.original.bak"
for %%I in ("%TARGET_DIR%\..\..") do set "GAME_DIR=%%~fI"
set "GAME_EXE=%GAME_DIR%\BongoCat.exe"

call :banner
call :log INFO "Source DLL"
call :path "%SOURCE_DLL%"
call :log INFO "Target DLL"
call :path "%TARGET_DLL%"

if not exist "%SOURCE_DLL%" (
    set "ERROR_MESSAGE=Patched DLL not found"
    set "ERROR_DETAIL=%SOURCE_DLL%"
    goto :fail
)

if not exist "%TARGET_DIR%\" (
    set "ERROR_MESSAGE=Target folder not found"
    set "ERROR_DETAIL=%TARGET_DIR%"
    goto :fail
)

call :log RUN "Stop BongoCat.exe"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $processes = Get-Process -Name 'BongoCat' -ErrorAction SilentlyContinue; if (-not $processes) { Write-Host '[OK] BongoCat.exe was not running'; exit 0 }; Stop-Process -InputObject $processes -Force; Start-Sleep -Milliseconds 500; if (Get-Process -Name 'BongoCat' -ErrorAction SilentlyContinue) { Write-Host '[ERR] BongoCat.exe is still running'; exit 1 }; Write-Host '[OK] BongoCat.exe stopped'"
if errorlevel 1 (
    call :prompt_elevate
    if errorlevel 1 exit /b 0
    set "ERROR_MESSAGE=Could not stop BongoCat.exe"
    set "ERROR_DETAIL=Close it manually or run this batch file as administrator."
    goto :fail
)

if exist "%TARGET_DLL%" (
    fc /B "%SOURCE_DLL%" "%TARGET_DLL%" >nul 2>&1
    if not errorlevel 1 (
        call :log OK "Patch already installed"
        goto :done
    )
)

if exist "%TARGET_DLL%" (
    if not exist "%BACKUP_DLL%" (
        call :log RUN "Create original DLL backup"
        copy /Y /B "%TARGET_DLL%" "%BACKUP_DLL%" >nul
        if errorlevel 1 (
            set "ERROR_MESSAGE=Backup failed. Run this batch file as administrator."
            set "ERROR_DETAIL=%BACKUP_DLL%"
            goto :fail
        )
        call :log OK "Backup created"
        call :path "%BACKUP_DLL%"
    ) else (
        call :log INFO "Existing backup kept"
        call :path "%BACKUP_DLL%"
    )
)

call :log RUN "Install patched DLL"
copy /Y /B "%SOURCE_DLL%" "%TARGET_DLL%" >nul
if errorlevel 1 (
    set "ERROR_MESSAGE=Copy failed. Run this batch file as administrator."
    set "ERROR_DETAIL=%TARGET_DLL%"
    goto :fail
)
call :log OK "Copy complete"

call :log RUN "Verify binary copy"
fc /B "%SOURCE_DLL%" "%TARGET_DLL%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MESSAGE=Copy verification failed"
    set "ERROR_DETAIL=%TARGET_DLL%"
    goto :fail
)
call :log OK "Verification passed"

goto :done

:usage
call :banner
call :log INFO "Usage"
echo       %~nx0 [Managed folder ^| Assembly-CSharp.dll] [--no-pause]
echo.
call :log INFO "Default target"
echo   %DEFAULT_TARGET_DIR%
exit /b 0

:prompt_elevate
net session >nul 2>&1
if not errorlevel 1 (
    call :log INFO "Already running as administrator"
    exit /b 0
)

if "%NO_PAUSE%"=="1" (
    call :log WARN "Administrator permissions required to stop BongoCat.exe"
    exit /b 0
)

echo.
call :log WARN "Administrator permissions may be required"
choice /C YN /N /M "[PROMPT] Relaunch installer as administrator? [Y/N] "
if errorlevel 2 exit /b 0

call :log RUN "Requesting UAC elevation"
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c ""%~f0"" %*' -WorkingDirectory '%CD%' -Verb RunAs"
if errorlevel 1 (
    call :log WARN "Could not open the administrator prompt"
    exit /b 0
)
exit /b 1

:fail
echo.
call :log ERR "%ERROR_MESSAGE%"
if not "%ERROR_DETAIL%"=="" call :path "%ERROR_DETAIL%"
call :maybe_pause
exit /b 1

:done
echo.
call :log OK "Installer complete"
call :log INFO "Target"
call :path "%TARGET_DLL%"
if exist "%BACKUP_DLL%" (
    call :log INFO "Backup"
    call :path "%BACKUP_DLL%"
)
call :launch_bongocat
call :maybe_pause
exit /b 0

:launch_bongocat
if not exist "%GAME_EXE%" (
    call :log WARN "BongoCat.exe not found"
    call :path "%GAME_EXE%"
    exit /b 0
)

call :log RUN "Relaunch BongoCat.exe"
start "" /D "%GAME_DIR%" "%GAME_EXE%"
if errorlevel 1 (
    call :log WARN "Could not relaunch BongoCat.exe"
    call :path "%GAME_EXE%"
    exit /b 0
)
call :log OK "Launch requested"
exit /b 0

:banner
echo.
echo +------------------------------------------------------------+
echo ^| BongoCat Auto Claimer Installer                           ^|
echo ^| patch deploy + process restart                            ^|
echo +------------------------------------------------------------+
echo.
exit /b 0

:log
echo [%~1] %~2
exit /b 0

:path
echo       "%~1"
exit /b 0

:maybe_pause
if not "%NO_PAUSE%"=="1" pause
exit /b 0
