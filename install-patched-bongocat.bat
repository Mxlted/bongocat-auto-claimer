@echo off
setlocal EnableExtensions

title BongoCat Auto Claimer Installer
color 0B >nul 2>&1

set "ROOT_DIR=%~dp0"
set "SOURCE_DLL=%ROOT_DIR%Assembly-CSharp.dll"
set "LOCAL_GRAB_BACKUP=%SOURCE_DLL%.before-installed-copy.bak"
set "PATCH_SCRIPT=%ROOT_DIR%tools\PatchAutoClaim.ps1"
set "CECIL_DLL=%ROOT_DIR%tools\ilspycmd\tools\net10.0\any\Mono.Cecil.dll"
set "WIN_POWERSHELL=%SystemRoot%\System32\WindowsPowerShell\v1.0\powershell.exe"
set "PATCH_POWERSHELL=%WIN_POWERSHELL%"
where pwsh.exe >nul 2>&1
if not errorlevel 1 set "PATCH_POWERSHELL=pwsh.exe"

set "DEFAULT_TARGET_DIR=C:\Program Files (x86)\Steam\steamapps\common\BongoCat\BongoCat_Data\Managed"
set "TARGET_INPUT="
set "TARGET_DIR="
set "TARGET_DLL="
set "SOURCE_FULL="
set "TARGET_FULL="
set "BACKUP_DLL="
set "GAME_DIR="
set "GAME_EXE="
set "NO_PAUSE="
set "MENU_MODE=1"
set "MENU_ERROR="
set "MENU_EMPTY_READ="
set "INSTALLED_MENU_ERROR="
set "INSTALLED_MENU_EMPTY_READ="
set "ACTION_ID="
set "ACTION_SWITCH="
set "ACTION_TITLE="
set "GRAB_INSTALLED="
set "PATCH_FIRST="
set "INSTALL_PATCH="
set "RELAUNCH_AFTER="
set "DONE_MESSAGE="

:parse_args
if "%~1"=="" goto :args_done
if /I "%~1"=="/?" goto :usage
if /I "%~1"=="-h" goto :usage
if /I "%~1"=="--help" goto :usage
if /I "%~1"=="--patch-install-relaunch" (
    set "ACTION_ID=patch-install-relaunch"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--install-relaunch" (
    set "ACTION_ID=install-relaunch"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--install-only" (
    set "ACTION_ID=install-only"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--patch-only" (
    set "ACTION_ID=patch-only"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--relaunch-only" (
    set "ACTION_ID=relaunch-only"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--grab-installed" (
    set "ACTION_ID=grab-installed"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--grab-patch-only" (
    set "ACTION_ID=grab-patch-only"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--grab-patch-install-relaunch" (
    set "ACTION_ID=grab-patch-install-relaunch"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--grab-patch-install-only" (
    set "ACTION_ID=grab-patch-install-only"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if /I "%~1"=="--no-pause" (
    set "NO_PAUSE=1"
    set "MENU_MODE="
    shift
    goto :parse_args
)
if "%TARGET_INPUT%"=="" (
    set "TARGET_INPUT=%~1"
    set "MENU_MODE="
    shift
    goto :parse_args
)

call :banner
set "ERROR_MESSAGE=Unexpected argument"
set "ERROR_DETAIL=%~1"
goto :fail_direct

:args_done
if "%TARGET_INPUT%"=="" (
    set "TARGET_DIR=%BONGOCAT_MANAGED_DIR%"
) else (
    set "TARGET_DIR=%TARGET_INPUT%"
)
if "%TARGET_DIR%"=="" set "TARGET_DIR=%DEFAULT_TARGET_DIR%"

set "TARGET_NAME="
if not "%TARGET_INPUT%"=="" for %%I in ("%TARGET_INPUT%") do set "TARGET_NAME=%%~nxI"
if /I "%TARGET_NAME%"=="Assembly-CSharp.dll" (
    set "TARGET_DLL=%TARGET_INPUT%"
    for %%I in ("%TARGET_INPUT%") do set "TARGET_DIR=%%~dpI"
) else (
    set "TARGET_DLL=%TARGET_DIR%\Assembly-CSharp.dll"
)
set "BACKUP_DLL=%TARGET_DLL%.original.bak"
for %%I in ("%TARGET_DIR%\..\..") do set "GAME_DIR=%%~fI"
set "GAME_EXE=%GAME_DIR%\BongoCat.exe"
for %%I in ("%SOURCE_DLL%") do set "SOURCE_FULL=%%~fI"
for %%I in ("%TARGET_DLL%") do set "TARGET_FULL=%%~fI"

if "%MENU_MODE%"=="1" goto :menu_loop

if "%ACTION_ID%"=="" set "ACTION_ID=install-relaunch"
call :select_action "%ACTION_ID%"
if errorlevel 1 exit /b 1

call :run_selected_action
set "EXIT_CODE=%ERRORLEVEL%"
call :maybe_pause
exit /b %EXIT_CODE%

:menu_loop
call :main_menu
if errorlevel 1 goto :menu_exit
call :run_selected_action
call :return_to_menu
goto :menu_loop

:menu_exit
cls
call :banner
call :log INFO "Exiting."
exit /b 0

:main_menu
cls
echo.
echo   +============================================================+
echo   ^|                                                            ^|
echo   ^|              BongoCat Auto Claimer Installer               ^|
echo   ^|                                                            ^|
echo   +============================================================+
echo.
echo     1. Patch local DLL, install patch, relaunch
echo        Refresh .\Assembly-CSharp.dll first, then deploy it.
echo.
echo     2. Install existing patch, relaunch
echo        Copy the current .\Assembly-CSharp.dll into the game.
echo.
echo     3. Install existing patch only
echo        Copy the current .\Assembly-CSharp.dll and leave BongoCat closed.
echo.
echo     4. Patch local DLL only
echo        Update .\Assembly-CSharp.dll here and do not install.
echo.
echo     5. Relaunch only
echo        Restart BongoCat.exe without installing files.
echo.
echo     6. Installed DLL tools
echo        Grab the currently installed game DLL into this folder.
echo.
echo     7. Exit
echo.
echo   +------------------------------------------------------------+
echo     Target:
echo       %TARGET_DLL%
echo.
if not "%MENU_ERROR%"=="" (
    call :log WARN "%MENU_ERROR%"
    echo.
    set "MENU_ERROR="
)
set "MENU_CHOICE="
set /P "MENU_CHOICE=  Select an action [1-7], then press Enter: "
if errorlevel 1 (
    if "%MENU_EMPTY_READ%"=="1" exit /b 1
    set "MENU_EMPTY_READ=1"
    set "MENU_ERROR=No selection entered. Enter a number from 1 to 7."
    goto :main_menu
)
set "MENU_EMPTY_READ="

if "%MENU_CHOICE%"=="1" (
    call :select_action patch-install-relaunch
    exit /b 0
)
if "%MENU_CHOICE%"=="2" (
    call :select_action install-relaunch
    exit /b 0
)
if "%MENU_CHOICE%"=="3" (
    call :select_action install-only
    exit /b 0
)
if "%MENU_CHOICE%"=="4" (
    call :select_action patch-only
    exit /b 0
)
if "%MENU_CHOICE%"=="5" (
    call :select_action relaunch-only
    exit /b 0
)
if "%MENU_CHOICE%"=="6" (
    call :installed_dll_menu
    if errorlevel 2 goto :main_menu
    exit /b 0
)
if "%MENU_CHOICE%"=="7" exit /b 1
if /I "%MENU_CHOICE%"=="Q" exit /b 1

set "MENU_ERROR=Invalid selection. Enter a number from 1 to 7."
set "MENU_EMPTY_READ="
goto :main_menu

:installed_dll_menu
cls
echo.
echo   +============================================================+
echo   ^|                                                            ^|
echo   ^|                 Installed DLL Tools                        ^|
echo   ^|                                                            ^|
echo   +============================================================+
echo.
echo     1. Grab installed DLL only
echo        Copy the game DLL into this script folder.
echo.
echo     2. Grab installed DLL, patch local DLL
echo        Refresh .\Assembly-CSharp.dll, then patch it here.
echo.
echo     3. Grab installed DLL, patch, install, relaunch
echo        Full update flow for a fresh game DLL.
echo.
echo     4. Grab installed DLL, patch, install only
echo        Full update flow without relaunching BongoCat.
echo.
echo     5. Back
echo.
echo   +------------------------------------------------------------+
echo     Installed DLL:
echo       %TARGET_DLL%
echo.
echo     Local copy:
echo       %SOURCE_DLL%
echo.
if not "%INSTALLED_MENU_ERROR%"=="" (
    call :log WARN "%INSTALLED_MENU_ERROR%"
    echo.
    set "INSTALLED_MENU_ERROR="
)
set "INSTALLED_MENU_CHOICE="
set /P "INSTALLED_MENU_CHOICE=  Select an action [1-5], then press Enter: "
if errorlevel 1 (
    if "%INSTALLED_MENU_EMPTY_READ%"=="1" exit /b 2
    set "INSTALLED_MENU_EMPTY_READ=1"
    set "INSTALLED_MENU_ERROR=No selection entered. Enter a number from 1 to 5."
    goto :installed_dll_menu
)
set "INSTALLED_MENU_EMPTY_READ="

if "%INSTALLED_MENU_CHOICE%"=="1" (
    call :select_action grab-installed
    exit /b 0
)
if "%INSTALLED_MENU_CHOICE%"=="2" (
    call :select_action grab-patch-only
    exit /b 0
)
if "%INSTALLED_MENU_CHOICE%"=="3" (
    call :select_action grab-patch-install-relaunch
    exit /b 0
)
if "%INSTALLED_MENU_CHOICE%"=="4" (
    call :select_action grab-patch-install-only
    exit /b 0
)
if "%INSTALLED_MENU_CHOICE%"=="5" exit /b 2
if /I "%INSTALLED_MENU_CHOICE%"=="B" exit /b 2
if /I "%INSTALLED_MENU_CHOICE%"=="Q" exit /b 2

set "INSTALLED_MENU_ERROR=Invalid selection. Enter a number from 1 to 5."
set "INSTALLED_MENU_EMPTY_READ="
goto :installed_dll_menu

:select_action
set "ACTION_ID=%~1"
set "ACTION_SWITCH=--%~1"
set "GRAB_INSTALLED="
set "PATCH_FIRST="
set "INSTALL_PATCH="
set "RELAUNCH_AFTER="
set "ACTION_TITLE="
set "DONE_MESSAGE="

if /I "%ACTION_ID%"=="patch-install-relaunch" (
    set "PATCH_FIRST=1"
    set "INSTALL_PATCH=1"
    set "RELAUNCH_AFTER=1"
    set "ACTION_TITLE=Patch local DLL, install patch, relaunch"
    set "DONE_MESSAGE=Patch and install complete"
    exit /b 0
)
if /I "%ACTION_ID%"=="install-relaunch" (
    set "INSTALL_PATCH=1"
    set "RELAUNCH_AFTER=1"
    set "ACTION_TITLE=Install existing patch, relaunch"
    set "DONE_MESSAGE=Install complete"
    exit /b 0
)
if /I "%ACTION_ID%"=="install-only" (
    set "INSTALL_PATCH=1"
    set "ACTION_TITLE=Install existing patch only"
    set "DONE_MESSAGE=Install complete"
    exit /b 0
)
if /I "%ACTION_ID%"=="patch-only" (
    set "PATCH_FIRST=1"
    set "ACTION_TITLE=Patch local DLL only"
    set "DONE_MESSAGE=Local DLL patch complete"
    exit /b 0
)
if /I "%ACTION_ID%"=="relaunch-only" (
    set "RELAUNCH_AFTER=1"
    set "ACTION_TITLE=Relaunch only"
    set "DONE_MESSAGE=Relaunch requested"
    exit /b 0
)
if /I "%ACTION_ID%"=="grab-installed" (
    set "GRAB_INSTALLED=1"
    set "ACTION_TITLE=Grab installed DLL only"
    set "DONE_MESSAGE=Installed DLL copied to script folder"
    exit /b 0
)
if /I "%ACTION_ID%"=="grab-patch-only" (
    set "GRAB_INSTALLED=1"
    set "PATCH_FIRST=1"
    set "ACTION_TITLE=Grab installed DLL, patch local DLL"
    set "DONE_MESSAGE=Installed DLL copied and patched"
    exit /b 0
)
if /I "%ACTION_ID%"=="grab-patch-install-relaunch" (
    set "GRAB_INSTALLED=1"
    set "PATCH_FIRST=1"
    set "INSTALL_PATCH=1"
    set "RELAUNCH_AFTER=1"
    set "ACTION_TITLE=Grab installed DLL, patch, install, relaunch"
    set "DONE_MESSAGE=Installed DLL refreshed, patched, and installed"
    exit /b 0
)
if /I "%ACTION_ID%"=="grab-patch-install-only" (
    set "GRAB_INSTALLED=1"
    set "PATCH_FIRST=1"
    set "INSTALL_PATCH=1"
    set "ACTION_TITLE=Grab installed DLL, patch, install only"
    set "DONE_MESSAGE=Installed DLL refreshed, patched, and installed"
    exit /b 0
)

call :banner
set "ERROR_MESSAGE=Unknown action"
set "ERROR_DETAIL=%ACTION_ID%"
goto :fail_direct

:run_selected_action
if "%MENU_MODE%"=="1" cls
set "ERROR_MESSAGE="
set "ERROR_DETAIL="

call :banner
call :log INFO "Action"
echo       %ACTION_TITLE%
call :show_action_plan

if "%GRAB_INSTALLED%"=="1" (
    if not exist "%TARGET_DLL%" (
        set "ERROR_MESSAGE=Installed DLL not found"
        set "ERROR_DETAIL=%TARGET_DLL%"
        goto :fail
    )

    if /I "%SOURCE_FULL%"=="%TARGET_FULL%" (
        set "ERROR_MESSAGE=Installed DLL source matches the local destination"
        set "ERROR_DETAIL=%SOURCE_DLL%"
        goto :fail
    )

    call :grab_installed_dll
    if errorlevel 1 goto :fail
)

if "%PATCH_FIRST%"=="1" (
    if not exist "%SOURCE_DLL%" (
        set "ERROR_MESSAGE=Local DLL not found"
        set "ERROR_DETAIL=%SOURCE_DLL%"
        goto :fail
    )

    if not exist "%PATCH_SCRIPT%" (
        set "ERROR_MESSAGE=Patch script not found"
        set "ERROR_DETAIL=%PATCH_SCRIPT%"
        goto :fail
    )

    if not exist "%CECIL_DLL%" (
        set "ERROR_MESSAGE=Mono.Cecil dependency not found"
        set "ERROR_DETAIL=%CECIL_DLL%"
        goto :fail
    )

    call :patch_local_dll
    if errorlevel 1 goto :fail
)

if "%INSTALL_PATCH%"=="1" (
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
)

if "%INSTALL_PATCH%"=="1" (
    call :stop_bongocat
    if errorlevel 2 goto :delegated
    if errorlevel 1 goto :fail
) else (
    if "%RELAUNCH_AFTER%"=="1" (
        call :stop_bongocat
        if errorlevel 2 goto :delegated
        if errorlevel 1 goto :fail
    )
)

if not "%INSTALL_PATCH%"=="1" goto :done

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
            call :prompt_elevate
            if errorlevel 1 goto :delegated
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
    call :prompt_elevate
    if errorlevel 1 goto :delegated
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

:show_action_plan
if "%GRAB_INSTALLED%"=="1" (
    call :log INFO "Grab installed DLL"
    echo       Enabled
    call :log INFO "Installed DLL"
    call :path "%TARGET_DLL%"
) else (
    call :log INFO "Grab installed DLL"
    echo       Skipped
)

call :log INFO "Local DLL"
call :path "%SOURCE_DLL%"

if "%INSTALL_PATCH%"=="1" (
    call :log INFO "Target DLL"
    call :path "%TARGET_DLL%"
)

if "%PATCH_FIRST%"=="1" (
    call :log INFO "Patch step"
    echo       Enabled
) else (
    call :log INFO "Patch step"
    echo       Skipped
)

if "%INSTALL_PATCH%"=="1" (
    call :log INFO "Install step"
    echo       Enabled
) else (
    call :log INFO "Install step"
    echo       Skipped
)

if "%RELAUNCH_AFTER%"=="1" (
    call :log INFO "Relaunch"
    echo       Enabled
) else (
    call :log INFO "Relaunch"
    echo       Skipped
)
exit /b 0

:usage
call :banner
call :log INFO "Usage"
echo       %~nx0 [Managed folder ^| Assembly-CSharp.dll] [--no-pause]
echo       %~nx0 [action] [Managed folder ^| Assembly-CSharp.dll] [--no-pause]
echo.
call :log INFO "Default target"
echo   %DEFAULT_TARGET_DIR%
echo.
call :log INFO "Menu"
echo   Run %~nx0 without arguments to open the terminal menu.
echo.
call :log INFO "Actions"
echo   --patch-install-relaunch
echo   --install-relaunch
echo   --install-only
echo   --patch-only
echo   --relaunch-only
echo   --grab-installed
echo   --grab-patch-only
echo   --grab-patch-install-relaunch
echo   --grab-patch-install-only
exit /b 0

:grab_installed_dll
call :log RUN "Copy installed DLL to script folder"
if exist "%SOURCE_DLL%" (
    fc /B "%TARGET_DLL%" "%SOURCE_DLL%" >nul 2>&1
    if not errorlevel 1 (
        call :log OK "Local DLL already matches installed DLL"
        exit /b 0
    )

    if not exist "%LOCAL_GRAB_BACKUP%" (
        call :log RUN "Create local DLL backup"
        copy /Y /B "%SOURCE_DLL%" "%LOCAL_GRAB_BACKUP%" >nul
        if errorlevel 1 (
            set "ERROR_MESSAGE=Local DLL backup failed"
            set "ERROR_DETAIL=%LOCAL_GRAB_BACKUP%"
            exit /b 1
        )
        call :log OK "Local backup created"
        call :path "%LOCAL_GRAB_BACKUP%"
    ) else (
        call :log INFO "Existing local backup kept"
        call :path "%LOCAL_GRAB_BACKUP%"
    )
)

copy /Y /B "%TARGET_DLL%" "%SOURCE_DLL%" >nul
if errorlevel 1 (
    set "ERROR_MESSAGE=Could not copy installed DLL into script folder"
    set "ERROR_DETAIL=%SOURCE_DLL%"
    exit /b 1
)

fc /B "%TARGET_DLL%" "%SOURCE_DLL%" >nul 2>&1
if errorlevel 1 (
    set "ERROR_MESSAGE=Installed DLL copy verification failed"
    set "ERROR_DETAIL=%SOURCE_DLL%"
    exit /b 1
)

call :log OK "Installed DLL copied"
call :path "%SOURCE_DLL%"
exit /b 0

:patch_local_dll
call :log RUN "Patch local Assembly-CSharp.dll"
"%PATCH_POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -File "%PATCH_SCRIPT%" -AssemblyPath "%SOURCE_DLL%" -CecilPath "%CECIL_DLL%"
if errorlevel 1 (
    set "ERROR_MESSAGE=Local DLL patch failed"
    set "ERROR_DETAIL=%SOURCE_DLL%"
    exit /b 1
)
call :log OK "Local DLL patched"
exit /b 0

:stop_bongocat
call :log RUN "Stop BongoCat.exe"
"%WIN_POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command "$ErrorActionPreference = 'Stop'; $processes = Get-Process -Name 'BongoCat' -ErrorAction SilentlyContinue; if (-not $processes) { Write-Host '[OK] BongoCat.exe was not running'; exit 0 }; Stop-Process -InputObject $processes -Force; Start-Sleep -Milliseconds 500; if (Get-Process -Name 'BongoCat' -ErrorAction SilentlyContinue) { Write-Host '[ERR] BongoCat.exe is still running'; exit 1 }; Write-Host '[OK] BongoCat.exe stopped'"
if errorlevel 1 (
    call :prompt_elevate
    if errorlevel 1 exit /b 2
    set "ERROR_MESSAGE=Could not stop BongoCat.exe"
    set "ERROR_DETAIL=Close it manually or run this batch file as administrator."
    exit /b 1
)
exit /b 0

:prompt_elevate
net session >nul 2>&1
if not errorlevel 1 (
    call :log INFO "Already running as administrator"
    exit /b 0
)

if "%NO_PAUSE%"=="1" (
    call :log WARN "Administrator permissions required for this action"
    exit /b 0
)

echo.
call :log WARN "Administrator permissions may be required"

:prompt_elevate_choice
set "ELEVATE_CHOICE="
set /P "ELEVATE_CHOICE=[PROMPT] Relaunch this action as administrator? [Y/N], then press Enter: "
if errorlevel 1 (
    if "%ELEVATE_EMPTY_READ%"=="1" exit /b 0
    set "ELEVATE_EMPTY_READ=1"
    call :log WARN "Enter Y or N."
    goto :prompt_elevate_choice
)
set "ELEVATE_EMPTY_READ="
if /I "%ELEVATE_CHOICE%"=="Y" goto :launch_elevated
if /I "%ELEVATE_CHOICE%"=="YES" goto :launch_elevated
if /I "%ELEVATE_CHOICE%"=="N" exit /b 0
if /I "%ELEVATE_CHOICE%"=="NO" exit /b 0
call :log WARN "Enter Y or N."
goto :prompt_elevate_choice

:launch_elevated
set "BCA_ELEVATE_SCRIPT=%~f0"
set "BCA_ELEVATE_ACTION=%ACTION_SWITCH%"
set "BCA_ELEVATE_TARGET=%TARGET_INPUT%"
set "BCA_ELEVATE_NO_PAUSE=%NO_PAUSE%"
set "BCA_ELEVATE_CWD=%CD%"

call :log RUN "Requesting UAC elevation"
"%WIN_POWERSHELL%" -NoProfile -ExecutionPolicy Bypass -Command "$argList = '/c ""' + $env:BCA_ELEVATE_SCRIPT + '"" ' + $env:BCA_ELEVATE_ACTION; if ($env:BCA_ELEVATE_TARGET) { $argList += ' ""' + $env:BCA_ELEVATE_TARGET + '""' }; if ($env:BCA_ELEVATE_NO_PAUSE) { $argList += ' --no-pause' }; Start-Process -FilePath $env:ComSpec -ArgumentList $argList -WorkingDirectory $env:BCA_ELEVATE_CWD -Verb RunAs"
if errorlevel 1 (
    call :log WARN "Could not open the administrator prompt"
    exit /b 0
)
exit /b 1

:delegated
echo.
call :log INFO "Administrator window opened for this action"
call :log INFO "Finish the elevated run there, then return here if needed."
exit /b 0

:fail_direct
call :fail
set "EXIT_CODE=%ERRORLEVEL%"
call :maybe_pause
exit /b %EXIT_CODE%

:fail
echo.
call :log ERR "%ERROR_MESSAGE%"
if not "%ERROR_DETAIL%"=="" call :path "%ERROR_DETAIL%"
exit /b 1

:done
echo.
call :log OK "%DONE_MESSAGE%"
if "%GRAB_INSTALLED%"=="1" (
    call :log INFO "Installed DLL"
    call :path "%TARGET_DLL%"
    call :log INFO "Local copy"
    call :path "%SOURCE_DLL%"
    if exist "%LOCAL_GRAB_BACKUP%" (
        call :log INFO "Local backup"
        call :path "%LOCAL_GRAB_BACKUP%"
    )
)
if "%PATCH_FIRST%"=="1" (
    call :log INFO "Local DLL"
    call :path "%SOURCE_DLL%"
)
if "%INSTALL_PATCH%"=="1" (
    call :log INFO "Target"
    call :path "%TARGET_DLL%"
    if exist "%BACKUP_DLL%" (
        call :log INFO "Backup"
        call :path "%BACKUP_DLL%"
    )
)
if "%RELAUNCH_AFTER%"=="1" call :launch_bongocat
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

:return_to_menu
echo.
set "RETURN_CHOICE="
set /P "RETURN_CHOICE=  Press Enter to return to the menu..."
exit /b 0

:maybe_pause
if not "%NO_PAUSE%"=="1" pause
exit /b 0
