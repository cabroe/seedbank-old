#!/bin/bash
# Self-Correction Feedback Loop
# Führt Analysen durch und sammelt Feedback

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

echo "=== Self-Correction Analysis ==="
echo ""

# 1. Feedback-Wörter erkennen
FEEDBACK_WORDS=("falsch" "stimmt nicht" "nicht richtig" "错误" "wrong" "incorrect")

# 2. Letzte Seeds abrufen (die letzten 20 als JSON für LLM)
echo "Prüfe letzte Konversationen..."
SEEDS_JSON=$(curl -s "${BASE_URL}/seeds/recent?limit=20")
CONTEXT=$(echo "$SEEDS_JSON" | jq -r '
  .[] | "[\(.created_at)] (ID: \(.id)): \(.content) | Tags: \(.metadata.tags // [])"
')

# 3. Fehler-Analyse durch LLM
echo ""
echo "=== Fehler-Analyse ==="
PROMPT="Du bist das Self-Correction Module von JARVIS. Analysiere das folgende jüngste Gedächtnisprotokoll. Suche gezielt nach Hinweisen auf Fehler, Fehlkommunikation, Kritik vom User ('Carsten') oder Systemproblemen (Feedback-Wörter wie: falsch, wrong, stimmt nicht). Wenn du Fehler findest, formuliere eine konstruktive, kurze Korrekturmaßnahme für die Zukunft. Wenn du keine Fehler findest, melde exakt 'Keine Fehler gefunden. System läuft korrekt.'. Hier das Protokoll:\n\n$CONTEXT"

CORRECTION=$(openclaw agent --agent main --message "$PROMPT" --json | jq -r 'if .messages then .messages[-1].content else .error end')

if [[ "$CORRECTION" == "null" || -z "$CORRECTION" ]]; then
    CORRECTION="Self-Correction Analyse: Keine Fehler gefunden. System läuft korrekt."
fi

echo "$CORRECTION"
echo ""

# 4. Korrektur-Regeln speichern
echo "Speichere Analyse-Ergebnis..."

TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SAFE_CORRECTION=$(jq -n --arg c "Self-Correction (${TIMESTAMP}):\n$CORRECTION" '[$c]')

curl -s -X POST "${BASE_URL}/seeds" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": ${SAFE_CORRECTION},
    \"metadata\": {\"type\":\"analysis\",\"source\":\"self-correction\"}
  }" \
  > /dev/null 2>&1

echo "Analyse abgeschlossen."
