#!/bin/bash
# Metriken - Erweiterte Stats für JARVIS

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"
GOALS_SCRIPT="/home/jarvis/.openclaw/workspace/skills/goal-hierarchy/scripts/goals.sh"
EMOTION_SCRIPT="/home/jarvis/.openclaw/workspace/skills/emotion-engine/scripts/emotion.sh"

echo "=== Metriken ==="

# 1. Seeds zählen
STATS=$(curl -s "${BASE_URL}/stats")
SEEDS=$(echo "$STATS" | jq -r '.seeds // 0')
CONTEXTS=$(echo "$STATS" | jq -r '.agent_contexts // 0')

echo "Seeds: $SEEDS, Contexts: $CONTEXTS"

# 2. Aktive Goals
ACTIVE_GOALS=$($GOALS_SCRIPT list active 2>/dev/null | grep -c "active" || echo "0")
echo "Aktive Goals: $ACTIVE_GOALS"

# 3. Emotionen-Status
EMOTION=$($EMOTION_SCRIPT get jarvis 2>/dev/null)
VALENCE=$(echo "$EMOTION" | jq -r '.valence // 5.0')
AROUSAL=$(echo "$EMOTION" | jq -r '.arousal // 5.0')
DOMINANCE=$(echo "$EMOTION" | jq -r '.dominance // 5.0')
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
curl -s -X POST "${BASE_URL}/seeds" \
    -F "text=Metriken ${TIMESTAMP}: Seeds=$SEEDS, Contexts=$CONTEXTS, Goals=$ACTIVE_GOALS, Emotion=V${VALENCE}A${AROUSAL}D${DOMINANCE}" \
    -F 'textTypes=["text"]' \
    -F 'textSources=["cron"]' \
    -F "metadata={\"type\":\"metrik\",\"seeds\":${SEEDS},\"contexts\":${CONTEXTS},\"goals\":${ACTIVE_GOALS},\"valence\":${VALENCE},\"arousal\":${AROUSAL},\"dominance\":${DOMINANCE}}" \
    > /dev/null 2>&1

echo "Metriken gespeichert."
