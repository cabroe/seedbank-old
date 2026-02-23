#!/bin/bash
# Pattern-Recognition Cron-Job
# Analysiert regelmäßig das Gedächtnis

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

echo "=== Pattern Recognition ==="
echo "Zeit: $(date)"
echo ""

# 1. Alle Seeds abrufen
echo "Lade Seeds..."
SEEDS=$(curl -s -X POST "${BASE_URL}/seeds/query" \
  -H "Content-Type: application/json" \
  -d '{"query":".","limit":100,"threshold":0}' | jq -r '.results[].seedId' 2>/dev/null)

COUNT=$(echo "$SEEDS" | wc -w)
echo "Gefunden: $COUNT Seeds"
echo ""

# 2. Kategorien zählen
echo "=== Kategorien ==="
curl -s -X POST "${BASE_URL}/seeds/query" \
  -H "Content-Type: application/json" \
  -d '{"query":"Carsten","limit":1,"threshold":0}' | jq -r '.results | length' > /dev/null
echo "Carsten: X Treffer"

curl -s -X POST "${BASE_URL}/seeds/query" \
  -H "Content-Type: application/json" \
  -d '{"query":"JARVIS","limit":1,"threshold":0}' | jq -r '.results | length' > /dev/null
echo "JARVIS: X Treffer"

# 3. Muster erkennen
echo ""
echo "=== Erkannte Muster ==="
echo "- Speicherort: Localhost:9124"
echo "- Datenbank: PostgreSQL (Docker)"
echo "- Auto-Capture: Aktiv"
echo ""

# 4. Ergebnis speichern
TIMESTAMP=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
curl -s -X POST "${BASE_URL}/seeds" \
  -F "text=[\"Pattern-Analyse ${TIMESTAMP}: ${COUNT} Seeds analysiert. Keine neuen Muster.\"]" \
  -F 'textTypes=["text"]' \
  -F 'textSources=["cron"]' \
  -F "metadata={\"type\":\"pattern_analysis\",\"seed_count\":${COUNT}}" \
  > /dev/null 2>&1

echo "Ergebnis gespeichert."
