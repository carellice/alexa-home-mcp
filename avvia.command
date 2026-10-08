#!/bin/zsh
# Avvia (o riavvia) il servizio, lo registra per partire da solo al login del Mac e attiva Tailscale Funnel
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
LABEL="com.claude-alexa.server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
# Il log sta fuori dalla cartella: macOS impedisce ai servizi di scrivere in Scrivania e Documenti
LOG="$HOME/Library/Logs/claude-alexa.log"

# Toglie la registrazione precedente: può puntare a una cartella che non esiste più
if launchctl bootout "gui/$(id -u)/$LABEL" 2>/dev/null; then
    while launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; do sleep 1; done
fi

NODE="$(command -v node)"
if [[ -z "$NODE" ]]; then
    echo "Node.js non trovato: installalo da https://nodejs.org"
    exit 1
fi

# Rigenerato a ogni avvio, così segue la cartella se viene spostata
mkdir -p "$HOME/Library/LaunchAgents"
cat > "$PLIST" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$LABEL</string>
    <key>ProgramArguments</key>
    <array>
        <string>$NODE</string>
        <string>server.js</string>
    </array>
    <key>WorkingDirectory</key>
    <string>$PWD</string>
    <key>StandardOutPath</key>
    <string>$LOG</string>
    <key>StandardErrorPath</key>
    <string>$LOG</string>
    <key>RunAtLoad</key>
    <true/>
    <key>KeepAlive</key>
    <true/>
    <key>ThrottleInterval</key>
    <integer>30</integer>
</dict>
</plist>
EOF

: > "$LOG"
launchctl bootstrap "gui/$(id -u)" "$PLIST" || exit 1
sleep 8

if grep -q "Alexa collegata" "$LOG"; then
    echo "Server avviato e Alexa collegata."
elif grep -q "EPERM" "$LOG"; then
    echo "Il server non parte: macOS impedisce ai servizi di leggere Scrivania, Documenti e Download."
    echo "Sposta la cartella altrove (per esempio in $HOME) e rilancia questo script."
else
    echo "Server avviato, ma Alexa non è collegata:"
    cat "$LOG"
fi

# Tailscale Funnel: rende il server raggiungibile da internet. Resta attivo anche dopo i riavvii
TS="/Applications/Tailscale.app/Contents/MacOS/Tailscale"
[[ -x "$TS" ]] || TS="$(command -v tailscale)"
if [[ -z "$TS" ]]; then
    echo "Tailscale non trovato: installalo da https://tailscale.com/download"
    exit 1
fi
if ! "$TS" funnel status 2>/dev/null | grep -q "127.0.0.1:3000"; then
    "$TS" funnel --bg 3000 || { echo "Funnel non attivato: controlla che Tailscale sia aperto e connesso."; exit 1; }
fi
echo "Funnel attivo: $("$TS" funnel status 2>/dev/null | grep -m1 -o 'https://[^ ]*')"
echo "Puoi chiudere questa finestra."
