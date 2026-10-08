#!/bin/zsh
# Ferma il servizio fino al prossimo avvio manuale o al prossimo login del Mac
if launchctl bootout "gui/$(id -u)/com.claude-alexa.server" 2>/dev/null; then
    echo "Server fermato."
else
    echo "Il server non era attivo."
fi
