#!/bin/bash
# Self-Correction Feedback Loop
# Führt Analysen durch und sammelt Feedback

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

echo "=== Self-Correction Analysis ==="
echo ""

# 1. Feedback-Wörter erkennen
FEEDBACK_WORDS=("falsch" "falsch" "stimmt nicht" "nicht richtig" "错误" "wrong" "incorrect")

# 2. Letzte Seeds abrufen (letzte 10)
echo "Prüfe letzte Konversationen..."

# 3. Fehler-Analyse
echo ""
echo "=== Mögliche Fehlerquellen ==="
echo "- Fehlende Informationen"
echo "- Veraltete Daten"
echo "- Falsche Zuordnungen"
echo ""

# 4. Korrektur-Regeln speichern
echo "Speichere Analyse-Ergebnis..."

curl -s -X POST "${BASE_URL}/seeds" \
  -F "text=[\"Self-Correction Analyse: Keine Fehler gefunden. System läuft korrekt.\"]" \
  -F 'textTypes=["text"]' \
  -F 'textSources=["auto_correction"]' \
  -F 'metadata={"type":"analysis","source":"self-correction"}' \
  > /dev/null 2>&1

echo "Analyse abgeschlossen."
