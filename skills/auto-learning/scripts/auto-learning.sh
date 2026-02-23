#!/bin/bash
# Auto-Learning - Lernt aus Fehlern

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

echo "=== Auto-Learning ==="

# 1. Alle Seeds abrufen
SEEDS=$(curl -s -X POST "${BASE_URL}/seeds/query" \
  -H "Content-Type: application/json" \
  -d '{"query":".","limit":100,"threshold":0}')

# Prüfen ob Antwort leer ist
if [ -z "$SEEDS" ] || [ "$SEEDS" = "null" ]; then
  echo "Fehler: Keine Antwort von Neural Brain"
  exit 1
fi

# 2. Muster erkennen (mit Fallback auf 0 wenn leer)
CARSTEN=$(echo "$SEEDS" | jq '[.results[]? | select(.content? | contains("Carsten"))] | length' 2>/dev/null || echo "0")
JARVIS=$(echo "$SEEDS" | jq '[.results[]? | select(.content? | contains("JARVIS") or .content? | contains("ich bin"))] | length' 2>/dev/null || echo "0")
ERRORS=$(echo "$SEEDS" | jq '[.results[]? | select(.content? | contains("falsch") or .content? | contains("nicht") or .content? | contains("Error"))] | length' 2>/dev/null || echo "0")

echo "Carsten: $CARSTEN"
echo "JARVIS: $JARVIS"
echo "Fehler: $ERRORS"

# 3. Lernregel erstellen wenn genug Fehler
if [ -n "$ERRORS" ] && [ "$ERRORS" -gt 5 ] 2>/dev/null; then
  echo "Mehr Fehler erkannt - speichere Lernregel"
  curl -s -X POST "${BASE_URL}/seeds" \
    -F "text=Auto-Learning: $ERRORS Fehler gefunden. Mehr darauf achten." \
    -F 'textTypes=["text"]' \
    -F 'textSources=["cron"]' \
    -F "metadata={\"type\":\"learning\",\"fehler\":$ERRORS}" \
    > /dev/null 2>&1
fi

echo "Learning abgeschlossen."
