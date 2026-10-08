@echo off
rem Ferma il server chiudendo il processo in ascolto sulla porta 3000.
set TROVATO=0
for /f "tokens=5" %%p in ('netstat -ano ^| findstr /r /c:":3000 .*LISTENING"') do (
    taskkill /PID %%p /F >nul 2>&1
    set TROVATO=1
)

if "%TROVATO%"=="1" (
    echo Server fermato.
) else (
    echo Il server non era attivo.
)
pause
