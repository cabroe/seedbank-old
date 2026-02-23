#!/bin/bash
# Pattern-Recognition Cron-Job
# Analysiert regelmäßig das Gedächtnis

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

echo "=== Pattern Recognition ==="
echo "Zeit: $(date)"
echo ""

# 1. Alle Seeds abrufen (die letzten 50)
echo "Lade Speicher..."
SEEDS_JSON=$(curl -s "${BASE_URL}/seeds/recent?limit=50")
CONTEXT=$(echo "$SEEDS_JSON" | jq -r '
  .[] | "[\(.created_at)] (ID: \(.id)): \(.content) | Tags: \(.metadata.tags // [])"
')

COUNT=$(echo "$SEEDS_JSON" | jq 'length')
echo "Gefunden: $COUNT Seeds"
echo ""

# 2. Muster erkennen
echo "=== Erkannte Muster ==="
PROMPT="Du bist der Pattern-Recognizer von JARVIS's Neural Brain System. Deine Aufgabe ist es, die folgenden jüngsten rohen Gedächtniseinträge zu analysieren und tiefliegende Muster zu erkennen (z.B. emotionale Tendenzen von Carsten, inhaltliche Schwerpunkte, wiederkehrende Probleme). Antworte ausschließlich mit einer kurzen, präzisen Liste (max. 3 Punkte) der wichtigsten erkannten Metamuster in diesen Daten. Hier ist der Kontext:\n\n$CONTEXT"

PATTERN=$(openclaw agent --agent main --message "$PROMPT" --json | jq -r 'if .messages then .messages[-1].content else .error end')

if [[ "$PATTERN" == "null" || -z "$PATTERN" ]]; then
    PATTERN="Fehler bei der Analyse der Muster."
fi

echo "$PATTERN"
echo ""

# 3. Ergebnis speichern
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
SAFE_PATTERN=$(jq -n --arg p "Pattern-Analyse ${TIMESTAMP} (${COUNT} Seeds analysiert):\n$PATTERN" '[$p]')

curl -s -X POST "${BASE_URL}/seeds" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": ${SAFE_PATTERN},
    \"metadata\": {\"type\":\"pattern_analysis\",\"seed_count\":${COUNT}}
  }" \
  > /dev/null 2>&1

echo "Ergebnis gespeichert."
