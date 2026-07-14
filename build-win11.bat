@echo off
setlocal EnableExtensions
chcp 65001 >nul

title ChatGPT Windows 11 打包工具
cd /d "%~dp0"

echo.
echo ========================================
echo   ChatGPT Windows 11 一键打包
echo ========================================
echo.

where dotnet >nul 2>nul
if errorlevel 1 (
    echo [错误] 没有检测到 .NET SDK。
    echo 请安装 .NET 8 SDK x64：
    echo https://dotnet.microsoft.com/download/dotnet/8.0
    echo.
    pause
    exit /b 1
)

dotnet --list-sdks | findstr /b "8." >nul
if errorlevel 1 (
    echo [错误] 没有检测到 .NET 8 SDK。
    echo 请安装 .NET 8 SDK x64 后重新运行本脚本。
    echo https://dotnet.microsoft.com/download/dotnet/8.0
    echo.
    pause
    exit /b 1
)

set "PROJECT=%~dp0Windows\ChatGPTMonitor\ChatGPTMonitor.csproj"
set "PUBLISH=%~dp0Windows\ChatGPTMonitor\bin\publish-win11"
set "DIST=%~dp0dist-win11"

if not exist "%PROJECT%" (
    echo [错误] 找不到 Windows 项目：%PROJECT%
    pause
    exit /b 1
)

if exist "%PUBLISH%" rmdir /s /q "%PUBLISH%"
if not exist "%DIST%" mkdir "%DIST%"
if exist "%DIST%\ChatGPT.exe" del /q "%DIST%\ChatGPT.exe"

echo [1/2] 正在编译 Windows 11 x64 单文件程序...
dotnet publish "%PROJECT%" ^
    --configuration Release ^
    --runtime win-x64 ^
    --self-contained true ^
    --output "%PUBLISH%" ^
    -p:PublishSingleFile=true ^
    -p:IncludeNativeLibrariesForSelfExtract=true ^
    -p:DebugType=None ^
    -p:DebugSymbols=false

if errorlevel 1 (
    echo.
    echo [失败] 编译没有完成，请查看上方错误信息。
    pause
    exit /b 1
)

if not exist "%PUBLISH%\ChatGPT.exe" (
    echo [失败] 编译完成但没有找到 ChatGPT.exe。
    pause
    exit /b 1
)

echo [2/2] 正在整理输出文件...
copy /y "%PUBLISH%\ChatGPT.exe" "%DIST%\ChatGPT.exe" >nul

echo.
echo ========================================
echo   打包完成
echo   文件：%DIST%\ChatGPT.exe
echo ========================================
echo.
explorer /select,"%DIST%\ChatGPT.exe"
pause
exit /b 0
