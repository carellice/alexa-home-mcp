@echo off
rem Avvia il server in una finestra ridotta a icona.
rem Con l'argomento "auto" (avvio automatico) non aspetta un tasto alla fine.
cd /d "%~dp0"

netstat -ano | findstr /r /c:":3000 .*LISTENING" >nul
if not errorlevel 1 (
    echo Il server e' gia' attivo.
    goto funnel
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
    echo Server avviato e Alexa collegata.
)

:funnel
rem Tailscale Funnel: rende il server raggiungibile da internet. Resta attivo anche dopo i riavvii
where tailscale >nul 2>&1
if errorlevel 1 (
    echo Tailscale non trovato: installalo da https://tailscale.com/download
    goto fine
)
tailscale funnel status 2>nul | findstr /c:"127.0.0.1:3000" >nul
if errorlevel 1 tailscale funnel --bg 3000
tailscale funnel status 2>nul | findstr /c:"127.0.0.1:3000" >nul
if errorlevel 1 (
    echo Funnel non attivato: controlla che Tailscale sia aperto e connesso.
) else (
    echo Funnel attivo. Puoi chiudere questa finestra.
)

:fine
if not "%1"=="auto" pause
