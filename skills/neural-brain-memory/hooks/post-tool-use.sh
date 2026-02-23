#!/usr/bin/env bash
# Auto-Capture: Save conversation after AI turn (Neutron-compatible: POST /seeds multipart)

# Check if auto-capture is enabled (default: true)
NEURAL_BRAIN_AUTO_CAPTURE="${NEURAL_BRAIN_AUTO_CAPTURE:-true}"
[[ "$NEURAL_BRAIN_AUTO_CAPTURE" != "true" ]] && exit 0

BASE_URL="${NEURAL_BRAIN_URL:-http://localhost:9124}"
APP_ID="${NEUTRON_AGENT_ID:-}"
EXTERNAL_USER_ID="${YOUR_AGENT_IDENTIFIER:-1}"

QUERY_PARAMS=""
[[ -n "$APP_ID" ]] && QUERY_PARAMS="appId=${APP_ID}&externalUserId=${EXTERNAL_USER_ID}"

USER_MSG="${OPENCLAW_USER_MESSAGE:-}"
AI_RESP="${OPENCLAW_AI_RESPONSE:-}"
[[ -z "$USER_MSG" && -z "$AI_RESP" ]] && exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TITLE="Conversation - ${TS}"
CONTENT="User: ${USER_MSG}
Assistant: ${AI_RESP}"

if [[ -n "$QUERY_PARAMS" ]]; then
    curl -s -X POST "${BASE_URL}/seeds?${QUERY_PARAMS}" \
        -F "text=[\"${CONTENT}\"]" \
        -F 'textTypes=["text"]' \
        -F 'textSources=["auto_capture"]' \
        -F "textTitles=[\"${TITLE}\"]" > /dev/null 2>&1 &
else
    curl -s -X POST "${BASE_URL}/seeds" \
        -F "text=[\"${CONTENT}\"]" \
        -F 'textTypes=["text"]' \
        -F 'textSources=["auto_capture"]' \
        -F "textTitles=[\"${TITLE}\"]" > /dev/null 2>&1 &
fi
