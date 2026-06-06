@echo off
setlocal EnableExtensions

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

if not exist "%SOURCE_DLL%" (
    set "ERROR_MESSAGE=Patched DLL not found:"
    set "ERROR_DETAIL=%SOURCE_DLL%"
    goto :fail
)

if not exist "%TARGET_DIR%\" (
    set "ERROR_MESSAGE=Target folder not found:"
    set "ERROR_DETAIL=%TARGET_DIR%"
    goto :fail
)

echo Stopping BongoCat.exe...
"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $processes = Get-Process -Name 'BongoCat' -ErrorAction SilentlyContinue; if (-not $processes) { Write-Host 'BongoCat.exe was not running.'; exit 0 }; Stop-Process -InputObject $processes -Force; Start-Sleep -Milliseconds 500; if (Get-Process -Name 'BongoCat' -ErrorAction SilentlyContinue) { Write-Error 'BongoCat.exe is still running.'; exit 1 }; Write-Host 'BongoCat.exe stopped.'"
if errorlevel 1 (
    call :prompt_elevate
    if errorlevel 1 exit /b 0
    set "ERROR_MESSAGE=Could not stop BongoCat.exe."
    set "ERROR_DETAIL=Close it manually or run this batch file as administrator."
    goto :fail
)

if exist "%TARGET_DLL%" (
    fc /B "%SOURCE_DLL%" "%TARGET_DLL%" >nul 2>&1
    if not errorlevel 1 (
        echo Bongo Cat already has this patched DLL.
        goto :done
    )
)

if exist "%TARGET_DLL%" if not exist "%BACKUP_DLL%" (
    echo Backing up current Assembly-CSharp.dll...
    copy /Y /B "%TARGET_DLL%" "%BACKUP_DLL%" >nul
    if errorlevel 1 (
        set "ERROR_MESSAGE=Backup failed. Run this batch file as administrator."
        set "ERROR_DETAIL=%BACKUP_DLL%"
        goto :fail
    )
)

echo Installing patched Assembly-CSharp.dll...
copy /Y /B "%SOURCE_DLL%" "%TARGET_DLL%" >nul
if errorlevel 1 (
    set "ERROR_MESSAGE=Copy failed. Run this batch file as administrator."
    set "ERROR_DETAIL=%TARGET_DLL%"
    goto :fail
)

fc /B "%SOURCE_DLL%" "%TARGET_DLL%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MESSAGE=Copy verification failed:"
    set "ERROR_DETAIL=%TARGET_DLL%"
    goto :fail
)

echo Done. Patched DLL installed.
goto :done

:usage
echo Usage:
echo   %~nx0 [Managed folder ^| Assembly-CSharp.dll] [--no-pause]
echo.
echo With no path, this installs to:
echo   %DEFAULT_TARGET_DIR%
exit /b 0

:prompt_elevate
net session >nul 2>&1
if not errorlevel 1 (
    echo Already running as administrator.
    exit /b 0
)

if "%NO_PAUSE%"=="1" (
    echo BongoCat.exe could not be stopped without administrator permissions.
    exit /b 0
)

echo.
choice /C YN /N /M "BongoCat.exe could not be stopped. Relaunch this installer as administrator? [Y/N] "
if errorlevel 2 exit /b 0

"%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe" -NoProfile -ExecutionPolicy Bypass -Command "Start-Process -FilePath $env:ComSpec -ArgumentList '/c ""%~f0"" %*' -WorkingDirectory '%CD%' -Verb RunAs"
if errorlevel 1 (
    echo Could not open the administrator prompt.
    exit /b 0
)
exit /b 1

:fail
echo.
echo ERROR: %ERROR_MESSAGE%
if not "%ERROR_DETAIL%"=="" echo "%ERROR_DETAIL%"
call :maybe_pause
exit /b 1

:done
echo Target:
echo "%TARGET_DLL%"
if exist "%BACKUP_DLL%" (
    echo Backup:
    echo "%BACKUP_DLL%"
)
call :maybe_pause
exit /b 0

:maybe_pause
if not "%NO_PAUSE%"=="1" pause
exit /b 0
