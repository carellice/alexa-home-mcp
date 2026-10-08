@echo off
rem Avvia il server in una finestra ridotta a icona.
rem Con l'argomento "auto" (avvio automatico) non aspetta un tasto alla fine.
cd /d "%~dp0"

netstat -ano | findstr /r /c:":3000 .*LISTENING" >nul
if not errorlevel 1 (
    echo Il server e' gia' attivo.
    goto fine
)

where node >nul 2>&1
if errorlevel 1 (
    echo Node.js non trovato: installalo da https://nodejs.org
    goto fine
)

start "Claude Alexa" /min cmd /c "node server.js > server.log 2>&1"
timeout /t 8 /nobreak >nul

findstr /c:"Alexa collegata" server.log >nul
if errorlevel 1 (
    echo Server avviato, ma Alexa non e' collegata:
    type server.log
) else (
    echo Server avviato e Alexa collegata. Puoi chiudere questa finestra.
)

:fine
if not "%1"=="auto" pause
