@echo off
chcp 65001 >nul
setlocal EnableDelayedExpansion

:: ============================================================
:: Vampire Hunter Roguelite - Windows 启动脚本
:: 无需打开 Godot 编辑器，直接运行游戏
:: ============================================================

:: 0. 项目目录（脚本所在目录）
set "PROJECT_DIR=%~dp0"
if "%PROJECT_DIR:~-1%"=="\" set "PROJECT_DIR=%PROJECT_DIR:~0,-1%"

:: 1. 可在此手动指定 Godot 可执行文件路径
set "GODOT_PATH="

:: 2. 如果未指定，依次尝试常见路径
if not exist "%GODOT_PATH%" (
    set "GODOT_PATH=D:\games\Godot_v4.6.3-stable_win64_console.exe"
)
if not exist "%GODOT_PATH%" (
    set "GODOT_PATH=D:\games\Godot_v4.6.3-stable_win64.exe"
)
if not exist "%GODOT_PATH%" (
    set "GODOT_PATH=C:\Program Files\Godot\Godot.exe"
)
if not exist "%GODOT_PATH%" (
    set "GODOT_PATH=C:\Tools\Godot\Godot.exe"
)

:: 3. 在当前目录及向上 3 层目录搜索 Godot*.exe
if not exist "%GODOT_PATH%" (
    call :FindGodot "%~dp0" 3
)

:: 4. 在 PATH 中搜索 godot.exe / godot_console.exe
if not exist "%GODOT_PATH%" (
    for %%E in (godot.exe godot_console.exe Godot.exe Godot_console.exe) do (
        for %%I in ("%%~$PATH:E") do (
            if exist "%%~I" (
                set "GODOT_PATH=%%~I"
                goto :Found
            )
        )
    )
)

:Found
if not exist "%GODOT_PATH%" (
    echo [错误] 未找到 Godot 可执行文件。
    echo.
    echo 请尝试以下方式之一：
    echo   1. 修改本脚本顶部的 GODOT_PATH 变量为 Godot 实际路径。
    echo   2. 将 Godot 解压到 D:\games\Godot_v4.6.3-stable_win64.exe。
    echo   3. 把 Godot 可执行文件放到项目根目录或上层目录。
    echo   4. 将 Godot 所在目录加入系统 PATH。
    echo.
    pause
    exit /b 1
)

echo [信息] 使用 Godot: %GODOT_PATH%
echo [信息] 项目路径: %PROJECT_DIR%
echo.

"%GODOT_PATH%" --path "%PROJECT_DIR%" scenes/ui/main_menu.tscn

if errorlevel 1 (
    echo.
    echo [错误] 游戏运行失败，请检查上方错误信息。
    pause
)

exit /b 0

:: ============================================================
:: 子程序：在指定目录向上递归搜索 Godot*.exe
:: 参数1：起始目录  参数2：剩余递归层数
:: ============================================================
:FindGodot
set "START_DIR=%~1"
set /a "DEPTH=%~2"
if %DEPTH% lss 0 exit /b 0

for %%F in ("%START_DIR%\Godot*.exe") do (
    set "GODOT_PATH=%%~fF"
    exit /b 0
)

:: 向上层目录递归
set "PARENT=%START_DIR%"
for %%P in ("%START_DIR%\..") do set "PARENT=%%~fP"
if /I not "%PARENT%"=="%START_DIR%" (
    call :FindGodot "%PARENT%" %DEPTH%-1
)
exit /b 0
