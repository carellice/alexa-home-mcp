#!/bin/zsh
# Avvia il servizio e lo registra per partire da solo al login del Mac
cd "$(dirname "$0")"
export PATH="/opt/homebrew/bin:/usr/local/bin:$PATH"
LABEL="com.claude-alexa.server"
PLIST="$HOME/Library/LaunchAgents/$LABEL.plist"
# Il log sta fuori dalla cartella: macOS impedisce ai servizi di scrivere in Scrivania e Documenti
LOG="$HOME/Library/Logs/claude-alexa.log"

if launchctl print "gui/$(id -u)/$LABEL" >/dev/null 2>&1; then
    echo "Il server è già attivo."
    exit 0
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
    echo "Server avviato e Alexa collegata. Puoi chiudere questa finestra."
else
    echo "Server avviato, ma Alexa non è collegata:"
    cat "$LOG"
fi
