@echo off
title OpenCode USB - Diagnostics
set "USB_ROOT=%~dp0"
if "%USB_ROOT:~-1%"=="\" set "USB_ROOT=%USB_ROOT:~0,-1%"

echo.
echo  ===============================================
echo    OpenCode Portable USB - Diagnostics
echo  ===============================================
echo.
echo  This collects information about why OpenCode
echo  will not start on this PC.
echo.
echo  Nothing is written to this computer - the report
echo  is saved onto the USB stick itself.
echo.

powershell.exe -NoLogo -NoProfile -ExecutionPolicy Bypass -File "%USB_ROOT%\bin\diagnose.ps1" -UsbRoot "%USB_ROOT%"

echo.
echo  ===============================================
echo    Done. Send this file back:
echo      %USB_ROOT%\diagnostic-report.txt
echo  ===============================================
echo.
pause
