#!/bin/bash
# Metriken - Erweiterte Stats für JARVIS

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
BASE_DIR="$SCRIPT_DIR/../.."
GOALS_SCRIPT="$BASE_DIR/neural-brain-goal-hierarchy/scripts/goals.sh"
EMOTION_SCRIPT="$BASE_DIR/neural-brain-emotion-engine/scripts/neural-brain-emotion.sh"

echo "=== Metriken ==="

# 1. Seeds zählen
STATS=$(curl -s "${BASE_URL}/stats")
SEEDS=$(echo "$STATS" | jq -r '.seeds' 2>/dev/null || echo "0")
if [ "$SEEDS" = "null" ] || [ -z "$SEEDS" ]; then SEEDS=0; fi
CONTEXTS=$(echo "$STATS" | jq -r '.agent_contexts' 2>/dev/null || echo "0")
if [ "$CONTEXTS" = "null" ] || [ -z "$CONTEXTS" ]; then CONTEXTS=0; fi

echo "Seeds: $SEEDS, Contexts: $CONTEXTS"

# 2. Aktive Goals
ACTIVE_GOALS=$($GOALS_SCRIPT list active 2>/dev/null | grep -c "active" || true)
echo "Aktive Goals: $ACTIVE_GOALS"

# 3. Emotionen-Status
EMOTION=$($EMOTION_SCRIPT get jarvis 2>/dev/null)
VALENCE=$(echo "$EMOTION" | jq -r '.valence' 2>/dev/null || echo "5.0")
if [ "$VALENCE" = "null" ] || [ -z "$VALENCE" ]; then VALENCE=5.0; fi
AROUSAL=$(echo "$EMOTION" | jq -r '.arousal' 2>/dev/null || echo "5.0")
if [ "$AROUSAL" = "null" ] || [ -z "$AROUSAL" ]; then AROUSAL=5.0; fi
DOMINANCE=$(echo "$EMOTION" | jq -r '.dominance' 2>/dev/null || echo "5.0")
if [ "$DOMINANCE" = "null" ] || [ -z "$DOMINANCE" ]; then DOMINANCE=5.0; fi
echo "Emotionen: V=$VALENCE, A=$AROUSAL, D=$DOMINANCE"

# 4. Letzten User-Input finden
LAST=$(curl -s -X POST "${BASE_URL}/seeds/query" \
  -H "Content-Type: application/json" \
  -d '{"query":"User:","limit":1,"threshold":0}' | jq -r '.results[0].content')
echo "Letzter Input: ${LAST:0:50}..."

# 5. Cron-Status
LOG_DIR="/home/jarvis/.openclaw/workspace/logs"
CRON_COUNT=$(ls -1 $LOG_DIR/cron-*.log 2>/dev/null | wc -l)
CRON_ERRORS=$(grep -rci "error\|fail" $LOG_DIR/ 2>/dev/null | cut -d: -f2 | paste -sd+ | bc 2>/dev/null || echo "0")
echo "Cron-Jobs: $CRON_COUNT | Fehler: $CRON_ERRORS"

# 6. Speichern als Seed
TIMESTAMP=$(date "+%Y-%m-%d %H:%M")
PAYLOAD=$(jq -n --arg content "Metriken ${TIMESTAMP}: Seeds=$SEEDS, Contexts=$CONTEXTS, Goals=$ACTIVE_GOALS, Emotion=V${VALENCE}A${AROUSAL}D${DOMINANCE}" \
  --argjson meta "{\"type\":\"metrik\",\"seeds\":${SEEDS},\"contexts\":${CONTEXTS},\"goals\":${ACTIVE_GOALS},\"valence\":${VALENCE},\"arousal\":${AROUSAL},\"dominance\":${DOMINANCE}}" \
  '{content: $content, metadata: $meta}')

curl -s -X POST "${BASE_URL}/seeds" \
    -H "Content-Type: application/json" \
    -d "$PAYLOAD" \
    > /dev/null 2>&1

echo "Metriken gespeichert."
