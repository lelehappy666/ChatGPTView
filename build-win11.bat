@echo off
setlocal EnableExtensions
cd /d "%~dp0"
title ChatGPT Windows 11 Builder

echo.
echo ========================================
echo   ChatGPT Windows 11 Builder
echo ========================================
echo.

where dotnet >nul 2>nul
if errorlevel 1 goto no_dotnet

dotnet --list-sdks | findstr /b /c:"8." >nul
if errorlevel 1 goto no_sdk

set "PROJECT=%~dp0Windows\ChatGPTMonitor\ChatGPTMonitor.csproj"
set "PUBLISH=%~dp0Windows\ChatGPTMonitor\bin\publish-win11"
set "DIST=%~dp0dist-win11"

if not exist "%PROJECT%" goto no_project
if exist "%PUBLISH%" rmdir /s /q "%PUBLISH%"
if not exist "%DIST%" mkdir "%DIST%"
if exist "%DIST%\ChatGPT.exe" del /q "%DIST%\ChatGPT.exe"

echo [1/2] Building self-contained win-x64 executable...
dotnet publish "%PROJECT%" --configuration Release --runtime win-x64 --self-contained true --output "%PUBLISH%" -p:PublishSingleFile=true -p:IncludeNativeLibrariesForSelfExtract=true -p:DebugType=None -p:DebugSymbols=false
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

:no_dotnet
echo [ERROR] .NET SDK was not found.
echo Install .NET 8 SDK x64 from:
echo https://dotnet.microsoft.com/download/dotnet/8.0
goto failed

:no_sdk
echo [ERROR] .NET 8 SDK was not found.
echo Install .NET 8 SDK x64 from:
echo https://dotnet.microsoft.com/download/dotnet/8.0
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
