#!/usr/bin/env bash
# Auto-Capture: Save conversation after AI turn

# Check if auto-capture is enabled (default: true)
# Use environment variable or fallback to default
NEURAL_BRAIN_AUTO_CAPTURE="${NEURAL_BRAIN_AUTO_CAPTURE:-}"

BASE_URL="${NEURAL_BRAIN_URL:-}"
CONFIG_FILE="${HOME}/.config/neural-brain/credentials.json"

# Load credentials and settings
APP_ID="${NEURAL_BRAIN_AGENT_ID:-}"
EXTERNAL_USER_ID="${NEURAL_BRAIN_EXTERNAL_USER_ID:-}"

if [[ -f "$CONFIG_FILE" ]]; then
    [[ -z "$BASE_URL" ]] && BASE_URL=$(jq -r '.url // empty' "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$APP_ID" ]] && APP_ID=$(jq -r '.agent_id // empty' "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$EXTERNAL_USER_ID" ]] && EXTERNAL_USER_ID=$(jq -r '.external_user_id // empty' "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$NEURAL_BRAIN_AUTO_CAPTURE" ]] && NEURAL_BRAIN_AUTO_CAPTURE=$(jq -r '.auto_capture // "true"' "$CONFIG_FILE" 2>/dev/null || true)
fi

# Apply defaults
BASE_URL="${BASE_URL:-http://localhost:9124}"
EXTERNAL_USER_ID="${EXTERNAL_USER_ID:-1}"
NEURAL_BRAIN_AUTO_CAPTURE="${NEURAL_BRAIN_AUTO_CAPTURE:-true}"

# Exit if disabled or if essential configuration is missing
[[ "$NEURAL_BRAIN_AUTO_CAPTURE" != "true" ]] && exit 0
[[ -z "$APP_ID" ]] && exit 0

USER_MSG="${OPENCLAW_USER_MESSAGE:-}"
AI_RESP="${OPENCLAW_AI_RESPONSE:-}"

[[ -z "$USER_MSG" && -z "$AI_RESP" ]] && exit 0

TS=$(date -u +"%Y-%m-%dT%H:%M:%SZ")
TITLE="Conversation - ${TS}"
CONTENT="User: ${USER_MSG}
Assistant: ${AI_RESP}"

QUERY_PARAMS="appId=${APP_ID}&externalUserId=${EXTERNAL_USER_ID}"

# Save as seed in background
curl -s -X POST "${BASE_URL}/seeds?${QUERY_PARAMS}" \
    -F "text=[\"${CONTENT}\"]" \
    -F 'textTypes=["text"]' \
    -F 'textSources=["auto_capture"]' \
    -F "textTitles=[\"${TITLE}\"]" > /dev/null 2>&1 &
