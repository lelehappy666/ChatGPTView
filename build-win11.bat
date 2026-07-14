@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title ChatGPT Windows 11 Builder

echo.
echo ========================================
echo   ChatGPT Windows 11 Builder
echo ========================================
echo.

set "DOTNET_EXE="
set "LOCAL_DOTNET=%~dp0.tools\dotnet"
set "INSTALL_SCRIPT=%~dp0.tools\dotnet-install.ps1"

where dotnet >nul 2>nul
if errorlevel 1 goto check_local_sdk
dotnet --list-sdks | findstr /b /c:"8." >nul
if errorlevel 1 goto check_local_sdk
set "DOTNET_EXE=dotnet"
goto sdk_ready

:check_local_sdk
if not exist "%LOCAL_DOTNET%\dotnet.exe" goto ask_install_sdk
"%LOCAL_DOTNET%\dotnet.exe" --list-sdks | findstr /b /c:"8." >nul
if errorlevel 1 goto ask_install_sdk
set "DOTNET_EXE=%LOCAL_DOTNET%\dotnet.exe"
goto sdk_ready

:ask_install_sdk
echo .NET 8 SDK is required to build ChatGPT.exe.
echo It can be downloaded from Microsoft and installed locally in:
echo %LOCAL_DOTNET%
echo Administrator permission is not required.
echo.
choice /c YN /n /m "Download and install .NET 8 SDK now? [Y/N]: "
if errorlevel 2 goto install_declined
if errorlevel 1 goto install_sdk

:install_sdk
where powershell.exe >nul 2>nul
if errorlevel 1 goto no_powershell
if not exist "%~dp0.tools" mkdir "%~dp0.tools"

echo.
echo [SDK 1/3] Downloading the official Microsoft installer...
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -Command "$ProgressPreference='Continue'; Invoke-WebRequest -UseBasicParsing 'https://dot.net/v1/dotnet-install.ps1' -OutFile '%INSTALL_SCRIPT%'"
if errorlevel 1 goto installer_download_failed
if not exist "%INSTALL_SCRIPT%" goto installer_download_failed

echo.
echo [SDK 2/3] Downloading and installing .NET 8 SDK...
echo Download and extraction progress will be displayed below.
powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%INSTALL_SCRIPT%" -Channel 8.0 -Architecture x64 -InstallDir "%LOCAL_DOTNET%" -NoPath -Verbose
if errorlevel 1 goto sdk_install_failed

echo.
echo [SDK 3/3] Verifying the installed SDK...
if not exist "%LOCAL_DOTNET%\dotnet.exe" goto sdk_install_failed
"%LOCAL_DOTNET%\dotnet.exe" --list-sdks | findstr /b /c:"8." >nul
if errorlevel 1 goto sdk_install_failed
set "DOTNET_EXE=%LOCAL_DOTNET%\dotnet.exe"
echo .NET 8 SDK installation completed successfully.

:sdk_ready
echo Using .NET SDK:
"%DOTNET_EXE%" --version
if errorlevel 1 goto sdk_verify_failed
echo.

set "PROJECT=%~dp0Windows\ChatGPTMonitor\ChatGPTMonitor.csproj"
set "PUBLISH=%~dp0Windows\ChatGPTMonitor\bin\publish-win11"
set "DIST=%~dp0dist-win11"

if not exist "%PROJECT%" goto no_project
if exist "%PUBLISH%" rmdir /s /q "%PUBLISH%"
if not exist "%DIST%" mkdir "%DIST%"
if exist "%DIST%\ChatGPT.exe" del /q "%DIST%\ChatGPT.exe"

echo [1/2] Building self-contained win-x64 executable...
"%DOTNET_EXE%" publish "%PROJECT%" --configuration Release --runtime win-x64 --self-contained true --output "%PUBLISH%" -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false
if errorlevel 1 goto build_failed

if not exist "%PUBLISH%\ChatGPT.exe" goto exe_missing
echo [2/2] Copying final executable...
copy /y "%PUBLISH%\ChatGPT.exe" "%DIST%\ChatGPT.exe" >nul
if errorlevel 1 goto copy_failed

echo.
echo ========================================
echo   BUILD SUCCEEDED
echo   %DIST%\ChatGPT.exe
echo ========================================
echo.
explorer.exe /select,"%DIST%\ChatGPT.exe"
pause
exit /b 0

:install_declined
echo Installation was cancelled by the user.
goto failed

:no_powershell
echo [ERROR] Windows PowerShell was not found.
goto failed

:installer_download_failed
echo [ERROR] Failed to download the official .NET installer.
echo Check the network connection and run this BAT again.
goto failed

:sdk_install_failed
echo [ERROR] .NET 8 SDK installation or verification failed.
goto failed

:sdk_verify_failed
echo [ERROR] The selected dotnet executable cannot be started.
goto failed

:no_project
echo [ERROR] Project file was not found:
echo %PROJECT%
goto failed

:build_failed
echo [ERROR] dotnet publish failed. Review the errors above.
goto failed

:exe_missing
echo [ERROR] ChatGPT.exe was not generated.
goto failed

:copy_failed
echo [ERROR] Failed to copy ChatGPT.exe to dist-win11.

:failed
echo.
pause
exit /b 1
