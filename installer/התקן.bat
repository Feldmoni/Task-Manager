@echo off
rem התקנת "יומן משימות אישי" (אפליקציית Edge, ללא הרשאות מנהל)
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0install_journal.ps1"
