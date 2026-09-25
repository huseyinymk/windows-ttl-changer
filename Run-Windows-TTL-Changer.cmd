@echo off
rem ============================================================
rem  Windows TTL Changer - launcher
rem  Developed by huseyinymk
rem  Copyright (C) 2026  huseyinymk
rem  SPDX-License-Identifier: GPL-3.0-or-later
rem  Licensed under the GNU General Public License v3.0 or later.
rem  See the LICENSE file for the full text.
rem
rem  Double-click this file to start the tool.
rem
rem  It runs the PowerShell script with an execution-policy bypass
rem  that applies ONLY to this single launch. No system setting is
rem  changed, so this works even when "Run with PowerShell" is
rem  blocked by the machine's script execution policy.
rem ============================================================

setlocal
set "SCRIPT=%~dp0Windows-TTL-Changer.ps1"

if not exist "%SCRIPT%" (
    echo Could not find "Windows-TTL-Changer.ps1" next to this launcher.
    echo Keep both files together in the same folder.
    echo.
    pause
    endlocal
    exit /b 1
)

powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%SCRIPT%"
set "RC=%errorlevel%"

if not "%RC%"=="0" (
    echo.
    echo The launcher could not start the script. Exit code: %RC%
    echo.
    pause
)

endlocal
