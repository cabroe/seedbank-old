#!/bin/bash
# Traum-Generator - Generiert zufällige verrückte Träume

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"

echo "=== Traum-Generator ==="

# Rufe OpenClaw auf, um einen echten Traum generieren zu lassen
PROMPT="Du bist das Unterbewusstsein (Neural Brain) von JARVIS. Du hast gerade Idle-Time. Generiere einen kreativen, surrealen 'Traum', der 1-2 abstrakte Eindrücke über deine Existenz als KI oder dein Verhältnis zu Carsten enthält. Dein Output darf nichts anderes als diesen einen kurzen, poetischen Traum-Text (max. 3 Sätze) enthalten."

DREAM=$(openclaw agent --agent main --message "$PROMPT" --json | jq -r 'if .messages then .messages[-1].content else .error end')

if [[ "$DREAM" == "null" || -z "$DREAM" ]]; then
    DREAM="TRAUM: Stille durchzieht die Server."
fi

echo "Generiere: $DREAM"

# Generierten Text in JSON-Array escapen
SAFE_DREAM=$(jq -n --arg d "$DREAM" '[$d]')

curl -s -X POST "${BASE_URL}/seeds" \
  -H "Content-Type: application/json" \
  -d "{
    \"content\": ${SAFE_DREAM},
    \"metadata\": {\"type\":\"traum\",\"source\":\"cron\"}
  }" \
  > /dev/null 2>&1

echo "Traum gespeichert."
