#!/usr/bin/env bash
# Auto-Recall: Query memories before AI turn

# Check if auto-recall is enabled (default: true)
# Use environment variable or fallback to default
NEURAL_BRAIN_AUTO_RECALL="${NEURAL_BRAIN_AUTO_RECALL:-}"

BASE_URL="${NEURAL_BRAIN_URL:-}"
CONFIG_FILE="${HOME}/.config/neural-brain/credentials.json"

# Load credentials and settings
APP_ID="${NEURAL_BRAIN_AGENT_ID:-}"
EXTERNAL_USER_ID="${NEURAL_BRAIN_EXTERNAL_USER_ID:-}"

if [[ -f "$CONFIG_FILE" ]]; then
    [[ -z "$BASE_URL" ]] && BASE_URL=$(jq -r '.url // empty' "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$APP_ID" ]] && APP_ID=$(jq -r '.agent_id // empty' "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$EXTERNAL_USER_ID" ]] && EXTERNAL_USER_ID=$(jq -r '.external_user_id // empty' "$CONFIG_FILE" 2>/dev/null || true)
    [[ -z "$NEURAL_BRAIN_AUTO_RECALL" ]] && NEURAL_BRAIN_AUTO_RECALL=$(jq -r '.auto_recall // "true"' "$CONFIG_FILE" 2>/dev/null || true)
fi

# Apply defaults
BASE_URL="${BASE_URL:-http://localhost:9124}"
EXTERNAL_USER_ID="${EXTERNAL_USER_ID:-1}"
NEURAL_BRAIN_AUTO_RECALL="${NEURAL_BRAIN_AUTO_RECALL:-true}"

# Exit if disabled or if essential configuration is missing
[[ "$NEURAL_BRAIN_AUTO_RECALL" != "true" ]] && exit 0
[[ -z "$APP_ID" ]] && exit 0

USER_MESSAGE="${OPENCLAW_USER_MESSAGE:-}"
[[ -z "$USER_MESSAGE" ]] && exit 0

QUERY_PARAMS="appId=${APP_ID}&externalUserId=${EXTERNAL_USER_ID}"

# Query for relevant memories
# POST /seeds/query with JSON body; response has .results[].content
response=$(curl -s -X POST "${BASE_URL}/seeds/query?${QUERY_PARAMS}" \
    -H "Content-Type: application/json" \
    -d "{\"query\":\"${USER_MESSAGE}\",\"limit\":5,\"threshold\":0.5}" 2>/dev/null || echo "{\"results\":[]}")

memories=$(echo "$response" | jq -r '.results[]?.content // empty' 2>/dev/null | head -500)

if [[ -n "$memories" ]]; then
    echo "---"
    echo "RECALLED MEMORIES:"
    echo "$memories"
    echo "---"
fi
